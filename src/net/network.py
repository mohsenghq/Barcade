"""ChessNet: AlphaZero-style residual CNN (az119 input, 4672 policy, value).

Kept deliberately boring for ONNX: only Conv, BatchNorm, ReLU, Add, MatMul,
Softmax (see docs/CHESS_AI_CONTRACT.md). fp32, NCHW, opset 17. Size chosen
for the 1080 Ti train side and phone inference: ~8 residual blocks x 128
filters is a few MB in fp32 and club-strength after warm-start + light RL.
"""

import torch
import torch.nn as nn


class ResidualBlock(nn.Module):
    def __init__(self, channels: int):
        super().__init__()
        self.conv1 = nn.Conv2d(channels, channels, 3, padding=1, bias=False)
        self.bn1 = nn.BatchNorm2d(channels)
        self.conv2 = nn.Conv2d(channels, channels, 3, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(channels)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        out = torch.relu(self.bn1(self.conv1(x)))
        out = self.bn2(self.conv2(out))
        return torch.relu(x + out)


class ChessNet(nn.Module):
    def __init__(self, blocks: int = 8, channels: int = 128):
        super().__init__()
        self.input_conv = nn.Conv2d(119, channels, 3, padding=1, bias=False)
        self.input_bn = nn.BatchNorm2d(channels)
        self.blocks = nn.Sequential(*[ResidualBlock(channels) for _ in range(blocks)])
        self.policy_conv = nn.Conv2d(channels, 73, 1, bias=False)
        self.policy_bn = nn.BatchNorm2d(73)
        self.value_conv = nn.Conv2d(channels, 1, 1, bias=False)
        self.value_bn = nn.BatchNorm2d(1)
        self.value_fc = nn.Linear(64, 256)
        self.value_out = nn.Linear(256, 1)

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        x = torch.relu(self.input_bn(self.input_conv(x)))
        x = self.blocks(x)
        policy = self.policy_bn(self.policy_conv(x))  # [B, 73, 8, 8]
        value = torch.relu(self.value_bn(self.value_conv(x)).flatten(1))
        value = torch.tanh(self.value_out(torch.relu(self.value_fc(value))))  # [B, 1]
        return policy, value

    def flat_logits(self, x: torch.Tensor) -> torch.Tensor:
        policy, _ = self.forward(x)
        return policy.reshape(policy.size(0), -1)  # [B, 4672]
