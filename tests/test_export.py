"""ONNX export contract tests (docs/CHESS_AI_CONTRACT.md)."""

from pathlib import Path

import onnx
import onnxruntime as ort
import numpy as np
import torch

from src.export.export_onnx import export_onnx
from src.net.network import ChessNet


def test_export_contract(tmp_path: Path):
    net = ChessNet(blocks=1, channels=8).eval()
    fp32, int8, manifest = export_onnx(
        net, tmp_path, torch_version="test", git_sha="abc", quantize=False)
    model = onnx.load(str(fp32))
    assert model.ir_version == 8
    assert model.opset_import[0].version == 17

    names = {i.name for i in model.graph.input}
    assert names == {"input"}
    out = {o.name: [d.dim_value for d in o.type.tensor_type.shape.dim]
           for o in model.graph.output}
    assert out == {"policy_logits": [1, 8, 8, 73], "value": [1, 1]}

    assert manifest["network_format_version"] == "az119/v1"
    assert manifest["input_shape"] == [1, 119, 8, 8]
    assert manifest["model_sha256"]

    sess = ort.InferenceSession(str(fp32), providers=["CPUExecutionProvider"])
    x = np.random.rand(1, 119, 8, 8).astype(np.float32)
    policy, value = sess.run(None, {"input": x})
    assert policy.shape == (1, 8, 8, 73)
    assert value.shape == (1, 1)
    assert -1.0 <= value[0][0] <= 1.0


def test_int8_quantize(tmp_path: Path):
    net = ChessNet(blocks=1, channels=8).eval()
    fp32, int8, _ = export_onnx(
        net, tmp_path, torch_version="test", git_sha="abc", quantize=True)
    assert int8 is not None and int8.exists()
    assert int8.stat().st_size < fp32.stat().st_size
    sess = ort.InferenceSession(str(int8), providers=["CPUExecutionProvider"])
    x = np.random.rand(1, 119, 8, 8).astype(np.float32)
    policy, value = sess.run(None, {"input": x})
    assert policy.shape == (1, 8, 8, 73)


def test_torch_matches_onnx(tmp_path: Path):
    net = ChessNet(blocks=1, channels=8).eval()
    fp32, _, _ = export_onnx(
        net, tmp_path, torch_version="test", git_sha="abc", quantize=False)
    sess = ort.InferenceSession(str(fp32), providers=["CPUExecutionProvider"])
    x = np.random.rand(1, 119, 8, 8).astype(np.float32)
    with torch.no_grad():
        torch_policy, torch_value = net(torch.from_numpy(x))
    ort_policy, ort_value = sess.run(None, {"input": x})
    np.testing.assert_allclose(ort_policy, torch_policy.numpy().transpose(0, 2, 3, 1),
                               atol=1e-4)
    np.testing.assert_allclose(ort_value, torch_value.numpy(), atol=1e-4)
