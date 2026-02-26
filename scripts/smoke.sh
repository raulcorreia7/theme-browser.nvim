#!/usr/bin/env bash
# smoke.sh - Run lightweight runtime smoke tests for theme-browser.nvim
#
# Usage: smoke.sh
#
# Requirements: nvim, jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY_PATH="$ROOT_DIR/lua/theme-browser/data/registry.json"
FIXTURE_DIR=""

cleanup() {
	if [[ -n "$FIXTURE_DIR" && -d "$FIXTURE_DIR" ]]; then
		rm -rf "$FIXTURE_DIR"
	fi
}
trap cleanup EXIT

check_bundled_registry() {
	if [[ ! -f "$REGISTRY_PATH" ]]; then
		echo "error: bundled registry not found: $REGISTRY_PATH" >&2
		exit 1
	fi

	local count
	count=$(jq 'length' "$REGISTRY_PATH")
	if [[ "$count" -eq 0 ]]; then
		echo "error: bundled registry is empty" >&2
		exit 1
	fi

	local has_tokyonight
	has_tokyonight=$(jq '[.[] | select(.name == "tokyonight")] | length' "$REGISTRY_PATH")
	if [[ "$has_tokyonight" -eq 0 ]]; then
		echo "error: bundled registry missing tokyonight" >&2
		exit 1
	fi

	echo "bundled registry OK ($count themes)"
}

create_fixture_colorscheme() {
	FIXTURE_DIR=$(mktemp -d -t tb-colors-XXXXXX)
	local colors_dir="$FIXTURE_DIR/colors"
	mkdir -p "$colors_dir"
	cat >"$colors_dir/tokyonight-night.vim" <<'VIM'
hi clear
let g:colors_name = "tokyonight-night"
VIM
}

run_nvim_smoke() {
	nvim --headless -u NONE \
		"+set rtp+=$FIXTURE_DIR" \
		"+set rtp+=$ROOT_DIR" \
		'+lua require("theme-browser").setup({ auto_load = false, package_manager = { enabled = false, mode = "plugin_only" } })' \
		'+lua local r=require("theme-browser.adapters.base").load_theme("tokyonight","night",{notify=false}); assert(r.ok, "theme load failed")' \
		+qa
	echo "runtime load OK (tokyonight:night via bundled registry)"
}

main() {
	cd "$ROOT_DIR"
	check_bundled_registry
	create_fixture_colorscheme
	run_nvim_smoke
}

main "$@"
