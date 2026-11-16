#!/usr/bin/env python3
"""Run designmd lint using local PATH / npx / pnpm dlx cache before falling back to pnpx."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


def find_designmd() -> list[str]:
    direct = shutil.which("designmd")
    if direct:
        return [direct]
    home = Path.home()
    for cache_root in (home / ".npm/_npx", home / "Library/Caches/pnpm/dlx"):
        if cache_root.is_dir():
            matches = sorted(
                cache_root.glob("**/node_modules/.bin/designmd"),
                key=lambda p: p.stat().st_mtime,
                reverse=True,
            )
            if matches:
                return [str(matches[0])]
    return ["pnpx", "@google/design.md"]


def main() -> int:
    target = sys.argv[1] if len(sys.argv) > 1 else "DESIGN.md"
    cmd = [*find_designmd(), "lint", target]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    if proc.returncode != 0:
        return proc.returncode
    payload = json.loads(proc.stdout)
    return 1 if payload.get("summary", {}).get("errors", 0) > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
