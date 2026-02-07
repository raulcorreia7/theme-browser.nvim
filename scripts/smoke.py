#!/usr/bin/env python3
"""Run lightweight runtime smoke tests for theme-browser.nvim."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile


def assert_curated_index(root: str) -> None:
    index_path = os.path.join(
        root, "theme-browser-registry", "curated", "dotfyle-top50.json"
    )
    with open(index_path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    if len(data) != 50:
        raise RuntimeError(f"expected 50 curated entries, got {len(data)}")
    print("curated index OK (50 themes)")


def create_fixture_colorscheme() -> str:
    fixture_dir = tempfile.mkdtemp(prefix="tb-colors-")
    colors_dir = os.path.join(fixture_dir, "colors")
    os.makedirs(colors_dir, exist_ok=True)
    colorscheme_path = os.path.join(colors_dir, "tokyonight-night.vim")
    with open(colorscheme_path, "w", encoding="utf-8") as handle:
        handle.write('hi clear\nlet g:colors_name = "tokyonight-night"\n')
    return fixture_dir


def run_nvim_smoke(root: str, fixture_dir: str) -> None:
    cmd = [
        "nvim",
        "--headless",
        "-u",
        "NONE",
        f"+set rtp+={fixture_dir}",
        f"+set rtp+={root}",
        '+lua require("theme-browser").setup({ auto_load = false, package_manager = { enabled = false, mode = "plugin_only" } })',
        '+lua local r=require("theme-browser.adapters.base").load_theme("tokyonight","night",{notify=false}); assert(r.ok, "theme load failed")',
        "+qa",
    ]
    subprocess.run(cmd, check=True)
    print("runtime load OK (tokyonight:night via curated index)")


def main() -> int:
    root = os.getcwd()
    fixture_dir = None

    try:
        assert_curated_index(root)
        fixture_dir = create_fixture_colorscheme()
        run_nvim_smoke(root, fixture_dir)
    finally:
        if fixture_dir and os.path.isdir(fixture_dir):
            shutil.rmtree(fixture_dir, ignore_errors=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
