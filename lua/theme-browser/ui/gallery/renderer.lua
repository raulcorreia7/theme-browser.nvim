local state_labels = require("theme-browser.ui.state_labels")

local M = {}

local function fit(text, width)
  if #text <= width then
    return text .. string.rep(" ", width - #text)
  end
  if width <= 1 then
    return text:sub(1, width)
  end
  return text:sub(1, width - 1) .. "~"
end

function M.render(session, state_mod, set_cursor_to_selected)
  if not session.bufnr or not vim.api.nvim_buf_is_valid(session.bufnr) then
    return
  end

  session.is_rendering = true

  local state = require("theme-browser.persistence.state")
  local lines = {}
  local snapshot = type(state.build_state_snapshot) == "function" and state.build_state_snapshot() or nil

  local left_width = 24
  for _, entry in ipairs(session.filtered_entries) do
    local variant = entry.variant or "default"
    local label = string.format("%s - %s", entry.name, variant)
    if #label > left_width then
      left_width = #label
    end
  end
  left_width = math.min(left_width + 2, 56)

  if #session.filtered_entries == 0 then
    session.row_offset = 0
    table.insert(lines, "No themes found")
    session.selected_idx = 1
  else
    session.row_offset = 3
    table.insert(lines, fit("Theme - Variant", left_width) .. " State")
    table.insert(lines, "[/] search  [n/N] next/prev  [Enter] apply  [p] preview  [i] install  [m] mark  [Esc] back")
    table.insert(lines, string.rep("-", left_width) .. " -----")
    for _, entry in ipairs(session.filtered_entries) do
      local variant = entry.variant or "default"
      local states = state_labels.format_readable_states(state, entry, snapshot)
      local label = fit(string.format("%s - %s", entry.name, variant), left_width)
      table.insert(lines, string.format("%s %s", label, states))
    end
  end

  table.insert(lines, "")
  table.insert(lines, "j/k, C-n/C-p, C-j/C-k move  gg/G bounds  / search  n/N next/prev")
  table.insert(lines, "<CR> apply  p preview  i install  m mark  q close")
  table.insert(lines, "<Esc>: clear search first, close when no search is active")
  table.insert(lines, "ThemeBrowserFocus re-focuses gallery if window focus is lost")
  table.insert(lines, "states: Current, Installed, Downloaded, Marked")

  vim.api.nvim_set_option_value("modifiable", true, { buf = session.bufnr })
  vim.api.nvim_buf_set_lines(session.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(session.bufnr, session.ns, 0, -1)

  if #session.filtered_entries > 0 and session.selected_idx >= 1 and session.selected_idx <= #session.filtered_entries then
    vim.api.nvim_buf_set_extmark(session.bufnr, session.ns, state_mod.index_to_row(session, session.selected_idx) - 1, 0, {
      line_hl_group = "PmenuSel",
      priority = 100,
    })
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = session.bufnr })

  if #session.filtered_entries > 0 then
    set_cursor_to_selected()
  end

  session.is_rendering = false
end

return M
