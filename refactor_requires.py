#!/usr/bin/env python3
"""Refactor gallery.lua to use cached requires at module level.
This replaces all `require("theme-browser.X")` with cached variables.
"""

import re

with open("lua/theme-browser/ui/gallery.lua", "r") as f:
    content = f.read()

# Define the pattern to match require() calls
require_pattern = re.compile(r'require\("theme-browser\.\w+?"\)')

# Define cache variables at the top
cache_vars = """local M = {}

local has_nui_popup, NuiPopup = pcall(require, "nui.popup")
local has_nui_split, NuiSplit = pcall(require, "nui.split")

local config_cache = nil
local state_cache = nil
local registry_cache = nil
local fuzzy_cache = nil

local gallery_popup = nil
local preview_split = nil
local all_themes = {}
local themes = {}
local current_index = 1
local search_query = ""
local fuzzy_matches = {}
local expanded_variants = {}
local marked_themes = {}
local filter = {
  mode = "all",
  tag = nil,
}
local original_buffer = nil
"""

# Replace all require() calls with cache variables
lines = content.split("\n")
output_lines = []

in_cache_section = False
line_num = 1

for line in lines:
    stripped = line.strip()

    # Check if we're pasting cache variable declarations section
    if line_num > 25 and stripped in cache_vars:
        in_cache_section = True

        # Match require() calls and replace them
        if require_pattern.search(stripped):
            module_match = require_pattern.search(stripped)

            # Generate cache variable name
            cache_var_name = f"{module_match.group(1)}_cache"

            # Determine if this is a new cache declaration
            if f"local {cache_var_name} = " in stripped and in_cache_section:
                output_lines.append(
                    f"  local {cache_var_name} = {cache_var_name} or require('{module_match.group(1)}')"
                )

                # Replace the require call with the cache variable
                replacement = (
                    f"local {cache_var_name} or require('{module_match.group(1)}')"
                )

                output_lines.append(replacement)

                print(f"Line {line_num}: {stripped[:60]}")
            else:
                output_lines.append(line)

    line_num += 1

# Write back to file
with open("lua/theme-browser/ui/gallery.lua", "w") as f:
    f.writelines(output_lines)

print(f"Refactored {len(output_lines)} lines")
print(f"Replaced require() calls with cached variables")
