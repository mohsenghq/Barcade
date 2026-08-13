"""Export ChessNet to the app's artifact contract (docs/CHESS_AI_CONTRACT.md):

chess_net.onnx  — fp32, opset 17, IR 8, inputs [1,119,8,8] NCHW, outputs
                  policy_logits [1,8,8,73] and value [1,1]
manifest.json   — sidecar with versioning (never ONNX metadata_props)
chess_net_int8.onnx — static-quantized QDQ/S8S8 build (the app's artifact)
"""

import hashlib
import json
import subprocess
from pathlib import Path

import onnx
import torch

from src.net.network import ChessNet

POLICY_SHAPE = [1, 8, 8, 73]


def _export_fp32(net: ChessNet, out: Path) -> None:
    net.eval()

    class _ExportNet(torch.nn.Module):
        def __init__(self, inner: torch.nn.Module):
            super().__init__()
            self.inner = inner

        def forward(self, x):
            policy, value = self.inner(x)
            return policy.permute(0, 2, 3, 1), value  # [1,8,8,73], [1,1]

    model = _ExportNet(net)
    x = torch.randn(1, 119, 8, 8)
    torch.onnx.export(
        model, x, str(out),
        input_names=["input"],
        output_names=["policy_logits", "value"],
        opset_version=17,
        do_constant_folding=True,
    )
    onnx_model = onnx.load(str(out))
    onnx_model.ir_version = 8
    onnx.checker.check_model(onnx_model)
    onnx.save(onnx_model, str(out))


def export_onnx(net: ChessNet, out_dir: Path, *, torch_version: str,
                git_sha: str, quantize: bool = True) -> tuple[Path, Path, dict]:
    out_dir.mkdir(parents=True, exist_ok=True)
    fp32 = out_dir / "chess_net.onnx"
    _export_fp32(net, fp32)
    onnx_ver = onnx.__version__

    int8 = None
    if quantize:
        int8 = out_dir / "chess_net_int8.onnx"
        _quantize(fp32, int8)

    artifact = int8 if int8 is not None else fp32
    manifest = {
        "schema_version": "1",
        "network_format_version": "az119/v1",
        "input_shape": [1, 119, 8, 8],
        "policy_shape": POLICY_SHAPE,
        "value_shape": [1, 1],
        "history": 8,
        "opset": 17,
        "onnx_version": onnx_ver,
        "torch_version": torch_version,
        "trainer_git_sha": git_sha,
        "model_sha256": hashlib.sha256(artifact.read_bytes()).hexdigest(),
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return fp32, int8, manifest


def _quantize(fp32: Path, int8: Path) -> None:
    """Static int8 QDQ quantization, calibrated on random inputs. Strength
    must be re-verified after quantization (see eval gate)."""
    from onnxruntime.quantization import QuantType, quantize_static

    quantize_static(str(fp32), str(int8),
                    calibration_data_reader=_RandomCalibReader(),
                    weight_type=QuantType.QInt8,
                    activation_type=QuantType.QInt8,
                    per_channel=True,
                    extra_options={"ActivationSymmetric": True})
    onnx.checker.check_model(str(int8))


class _RandomCalibReader:
    """500 random inputs are enough to pin static ranges on a small conv net."""

    def __init__(self):
        import numpy as np
        self._data = [{"input": np.random.rand(1, 119, 8, 8).astype(np.float32)}
                      for _ in range(500)]
        self._i = 0

    def get_next(self):
        if self._i >= len(self._data):
            return None
        item = self._data[self._i]
        self._i += 1
        return item
