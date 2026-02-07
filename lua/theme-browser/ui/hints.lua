local M = {}

local hints_shown = true

local default_hints = {
  { keys = "j/k", action = "Navigate" },
  { keys = "<CR>", action = "Select/Preview" },
  { keys = "q", action = "Quit" },
  { keys = "l", action = "Expand variants" },
  { keys = "m", action = "Mark for install" },
  { keys = "<C-f>", action = "Toggle filter" },
  { keys = "<C-b>", action = "Clear filters" },
  { keys = "gg/G", action = "Top/Bottom" },
  { keys = "<C-d>/<C-u>", action = "Page down/up" },
  { keys = "?", action = "Toggle help" },
}

---Render hints panel
---@return string Formatted hints
function M.render()
  if not hints_shown then
    return ""
  end

  local lines = {}
  table.insert(lines, "🔍 Hints:")

  local left_col = ""
  local right_col = ""

  for i, hint in ipairs(default_hints) do
    local entry = string.format("• %s: %s", hint.keys, hint.action)

    if i % 2 == 1 then
      left_col = left_col .. " " .. entry
    else
      right_col = right_col .. " " .. entry
    end

    if i % 2 == 0 then
      table.insert(lines, string.format("  %s  %s", left_col, right_col))
      left_col = ""
      right_col = ""
    end
  end

  if left_col ~= "" or right_col ~= "" then
    table.insert(lines, string.format("  %s  %s", left_col, right_col))
  end

  return table.concat(lines, "\n")
end

---Toggle hints visibility
function M.toggle()
  hints_shown = not hints_shown
end

---Check if hints are visible
---@return boolean
function M.is_shown()
  return hints_shown
end

---Set hints visibility
---@param shown boolean
function M.set_shown(shown)
  hints_shown = shown
end

return M
