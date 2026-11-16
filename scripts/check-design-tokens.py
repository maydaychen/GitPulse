#!/usr/bin/env python3
"""Verify that SwiftUI UI views consume TeaPulseTheme tokens instead of hardcoded visual hex literals."""

from __future__ import annotations

import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
SCAN_DIRS = ["TeaPulse", "SharedExtensionSupport", "TeaPulseWidgets", "TeaPulseShareExtension", "TeaPulseMacWidgets", "TeaPulseMacShareExtension"]
ALLOW_FILES = {
    pathlib.Path("SharedExtensionSupport/TeaPulseTheme.swift"),
}
FORBIDDEN_PATTERNS = [
    (re.compile(r"Color\s*\(\s*red:"), "Use TeaPulseTheme semantic color instead of Color(red:)"),
    (re.compile(r"#[0-9A-Fa-f]{6}\b"), "Use TeaPulseTheme semantic token instead of literal hex color"),
]


def main() -> int:
    violations: list[str] = []
    for rel_dir in SCAN_DIRS:
        base = REPO_ROOT / rel_dir
        if not base.exists():
            continue
        for swift_file in sorted(base.rglob("*.swift")):
            rel_path = swift_file.relative_to(REPO_ROOT)
            if rel_path in ALLOW_FILES:
                continue
            for idx, line in enumerate(swift_file.read_text(encoding="utf-8").splitlines(), start=1):
                for pattern, message in FORBIDDEN_PATTERNS:
                    if pattern.search(line):
                        violations.append(f"{rel_path}:{idx}: {message}")
    if violations:
        print("\n".join(violations))
        return 1
    print("OK: zero hardcoded color tokens outside TeaPulseTheme.swift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
