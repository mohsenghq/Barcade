"""CLI: the whole trainer pipeline.

  python -m src.cli fixtures <out_dir>      golden fixtures for the app
  python -m src.cli warmstart <pgn>         supervised warm-start
  python -m src.cli selfplay <ckpt>         RL fine-tune (resumes from ckpt)
  python -m src.cli eval <ckpt_a> <ckpt_b>  eval gate candidate vs champion
  python -m src.cli export <ckpt> <out_dir> ONNX fp32 + int8 + manifest
"""

import argparse
import subprocess
from pathlib import Path

import torch

from src.data.fixtures import emit_fixtures
from src.eval.strength import gate
from src.net.network import ChessNet
from src.train.train import train_selfplay, train_supervised

CKPT = "runs/chess_net.pt"


def _device() -> str:
    return "cuda" if torch.cuda.is_available() else "cpu"


def _save(net: ChessNet, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    torch.save(net.state_dict(), path)


def _load(net: ChessNet, path: Path) -> None:
    net.load_state_dict(torch.load(path, map_location=_device()))


def cmd_fixtures(args) -> None:
    fixtures = emit_fixtures(Path(args.out_dir))
    print(f"wrote {len(fixtures)} fixtures to {args.out_dir}")


def cmd_warmstart(args) -> None:
    net = ChessNet().to(_device())
    train_supervised(net, args.pgn, epochs=args.epochs, lr=args.lr,
                     device=_device(), sample=args.sample)
    _save(net, Path(args.ckpt))
    print(f"warm-start done -> {args.ckpt}")


def cmd_selfplay(args) -> None:
    net = ChessNet().to(_device())
    if Path(args.ckpt).exists():
        _load(net, Path(args.ckpt))
    train_selfplay(net, steps=args.steps, sims=args.sims,
                   device=_device())
    _save(net, Path(args.ckpt))
    print(f"self-play done -> {args.ckpt}")


def cmd_eval(args) -> None:
    a, b = ChessNet().to(_device()), ChessNet().to(_device())
    _load(a, Path(args.candidate))
    _load(b, Path(args.champion))
    result = gate(a, b, games=args.games, sims=args.sims)
    print(result)


def cmd_export(args) -> None:
    net = ChessNet().to(_device())
    _load(net, Path(args.ckpt))
    from src.export.export_onnx import export_onnx

    sha = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True,
                         text=True).stdout.strip()
    fp32, int8, manifest = export_onnx(
        net, Path(args.out_dir), torch_version=torch.__version__, git_sha=sha)
    print(f"fp32: {fp32} ({fp32.stat().st_size // 1024} KiB)")
    if int8:
        print(f"int8: {int8} ({int8.stat().st_size // 1024} KiB)")
    print(f"manifest: {args.out_dir}/manifest.json")


def main() -> None:
    p = argparse.ArgumentParser(description="Arcade Vault chess AI trainer")
    sub = p.add_subparsers(dest="cmd", required=True)

    f = sub.add_parser("fixtures")
    f.add_argument("out_dir")
    f.set_defaults(func=cmd_fixtures)

    w = sub.add_parser("warmstart")
    w.add_argument("pgn")
    w.add_argument("--ckpt", default=CKPT)
    w.add_argument("--epochs", type=int, default=1)
    w.add_argument("--lr", type=float, default=1e-3)
    w.add_argument("--sample", type=float, default=0.5)
    w.set_defaults(func=cmd_warmstart)

    s = sub.add_parser("selfplay")
    s.add_argument("--ckpt", default=CKPT)
    s.add_argument("--steps", type=int, default=100)
    s.add_argument("--sims", type=int, default=200)
    s.set_defaults(func=cmd_selfplay)

    e = sub.add_parser("eval")
    e.add_argument("candidate")
    e.add_argument("champion")
    e.add_argument("--games", type=int, default=40)
    e.add_argument("--sims", type=int, default=100)
    e.set_defaults(func=cmd_eval)

    x = sub.add_parser("export")
    x.add_argument("ckpt")
    x.add_argument("out_dir")
    x.set_defaults(func=cmd_export)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
