"""Environment guard for the training GPU.

The one check that must pass before anything else: torch must be the +cu126
build (Pascal sm_61 is dropped from newer CUDA lines) and CUDA must actually
be available. The default pip install of torch is CPU-only — this test is
the tripwire.
"""

import sys

import torch


def test_cuda_available():
    assert torch.cuda.is_available(), (
        "CUDA not available. Install torch==2.13.0+cu126 from the PyTorch index, "
        "not the CPU default wheel."
    )


def test_pascal_supported():
    arch = torch.cuda.get_arch_list()
    assert "sm_61" in arch, (
        f"torch build lacks Pascal sm_61 support (arch list: {arch}). "
        "Use torch==2.13.0+cu126."
    )


def test_device_name():
    print(f"\n[env] torch={torch.__version__} device={torch.cuda.get_device_name(0)} "
          f"arch={torch.cuda.get_arch_list()}")
