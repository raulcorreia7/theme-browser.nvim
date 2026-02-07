#!/usr/bin/env python3
"""Syntax-check Lua source files with luac."""

from __future__ import annotations

import os
import subprocess
import sys


def collect_lua_files(root: str) -> list[str]:
    files: list[str] = []
    for dirpath, _, filenames in os.walk(root):
        for filename in filenames:
            if filename.endswith(".lua"):
                files.append(os.path.join(dirpath, filename))
    files.sort()
    return files


def main() -> int:
    source_root = os.path.join(os.getcwd(), "lua")
    if not os.path.isdir(source_root):
        print(f"missing source directory: {source_root}")
        return 1

    files = collect_lua_files(source_root)
    errors: list[tuple[str, str]] = []

    for path in files:
        proc = subprocess.run(["luac", "-p", path], capture_output=True, text=True)
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip()
            errors.append((path, detail))

    print(f"checked={len(files)}")
    if errors:
        for path, detail in errors:
            print(f"{path}: {detail}")
        return 1

    print("luac syntax checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
