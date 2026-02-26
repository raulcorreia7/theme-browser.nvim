#!/usr/bin/env bash
# lint-lua.sh - Syntax-check Lua source files with luac
#
# Usage: lint-lua.sh
#
# Requirements: luac

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/lua"

if [[ ! -d "$SOURCE_DIR" ]]; then
	echo "missing source directory: $SOURCE_DIR" >&2
	exit 1
fi

count=0
errors=()

while IFS= read -r -d '' file; do
	((count++)) || true
	if ! luac -p "$file" 2>&1; then
		errors+=("$file")
	fi
done < <(find "$SOURCE_DIR" -name "*.lua" -type f -print0 | sort -z)

echo "checked=$count"

if [[ ${#errors[@]} -gt 0 ]]; then
	echo "luac syntax checks failed" >&2
	exit 1
fi

echo "luac syntax checks passed"
