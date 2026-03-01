#!/usr/bin/env bash
# test_runner.sh - Run tests in isolated Neovim environment
#
# Usage: ./scripts/test_runner.sh [test_file or directory]
#
# Creates isolated XDG directories to avoid affecting user's Neovim config

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
NVIM="${NVIM:-nvim}"
TEST_TARGET="${1:-tests}"
TEMP_DIR=""

cleanup() {
	if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
		rm -rf "$TEMP_DIR" 2>/dev/null || true
	fi
}

trap cleanup EXIT

create_isolated_env() {
	TEMP_DIR="$(mktemp -d -t theme-browser-tests.XXXXXX)"

	local CONFIG_HOME="$TEMP_DIR/config"
	local DATA_HOME="$TEMP_DIR/data"
	local CACHE_HOME="$TEMP_DIR/cache"
	local STATE_HOME="$TEMP_DIR/state"

	mkdir -p "$CONFIG_HOME/nvim/lua/plugins"
	mkdir -p "$DATA_HOME/nvim"
	mkdir -p "$CACHE_HOME/nvim"
	mkdir -p "$STATE_HOME/nvim"

	echo "$TEMP_DIR"
}

bootstrap_deps() {
	local DATA_HOME="$1"
	local PLENARY_PATH="$DATA_HOME/nvim/plenary.nvim"

	if [[ ! -d "$PLENARY_PATH" ]]; then
		git clone --depth=1 \
			https://github.com/nvim-lua/plenary.nvim.git \
			"$PLENARY_PATH"
	fi

	echo "$PLENARY_PATH"
}

create_init_lua() {
	local CONFIG_HOME="$1"
	local DATA_HOME="$2"
	local PLUGIN_ROOT="$3"
	local PLENARY_PATH="$4"

	cat >"$CONFIG_HOME/nvim/init.lua" <<EOF
vim.opt.rtp:prepend("$PLENARY_PATH")
vim.opt.rtp:prepend("$PLUGIN_ROOT")

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.env.XDG_CONFIG_HOME = "$CONFIG_HOME"
vim.env.XDG_DATA_HOME = "$DATA_HOME"
EOF
}

main() {
	echo "Setting up isolated test environment..."

	TEMP_DIR="$(create_isolated_env)"

	local CONFIG_HOME="$TEMP_DIR/config"
	local DATA_HOME="$TEMP_DIR/data"

	echo "Temp dir: $TEMP_DIR"

	local PLENARY_PATH
	PLENARY_PATH="$(bootstrap_deps "$DATA_HOME")"

	echo "Plenary path: $PLENARY_PATH"

	create_init_lua "$CONFIG_HOME" "$DATA_HOME" "$PLUGIN_ROOT" "$PLENARY_PATH"

	echo "Running tests in isolated environment..."
	echo ""

	export XDG_CONFIG_HOME="$CONFIG_HOME"
	export XDG_DATA_HOME="$DATA_HOME"
	export XDG_CACHE_HOME="$TEMP_DIR/cache"
	export XDG_STATE_HOME="$TEMP_DIR/state"
	export THEME_BROWSER_PLUGIN_ROOT="$PLUGIN_ROOT"

	local output_file="$TEMP_DIR/test_output.txt"

	set +e
	$NVIM --headless \
		-u "$CONFIG_HOME/nvim/init.lua" \
		-c "lua require('plenary.test_harness').test_directory('$PLUGIN_ROOT/tests', { minimal_init = '$CONFIG_HOME/nvim/init.lua' })" \
		+qa 2>&1 | tee "$output_file"
	set -e

	local total_failed=0
	while IFS= read -r line; do
		if [[ "$line" =~ Failed[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
			total_failed=$((total_failed + BASH_REMATCH[1]))
		fi
	done <"$output_file"

	echo ""
	if [[ "$total_failed" -eq 0 ]]; then
		echo "All tests passed"
	else
		echo "Tests failed: $total_failed failure(s)"
		exit 1
	fi
}

main "$@"
