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

local function split_state_tokens(text)
  if type(text) ~= "string" or text == "" or text == "Available" then
    return { "AVAILABLE" }
  end

  local tokens = {}
  for token in text:gmatch("[^,]+") do
    local trimmed = vim.trim(token)
    if trimmed ~= "" then
      table.insert(tokens, trimmed:upper())
    end
  end

  if #tokens == 0 then
    return { "AVAILABLE" }
  end

  return tokens
end

local function format_state_badges(text)
  local tokens = split_state_tokens(text)
  local badges = {}
  for _, token in ipairs(tokens) do
    table.insert(badges, string.format("[%s]", token))
  end
  return table.concat(badges, " "), tokens
end

local function pick_state_hl(tokens)
  local joined = table.concat(tokens, " ")
  if joined:find("CURRENT", 1, true) then
    return "ThemeBrowserStateCurrent"
  end
  if joined:find("INSTALLED", 1, true) then
    return "ThemeBrowserStateInstalled"
  end
  if joined:find("DOWNLOADED", 1, true) then
    return "ThemeBrowserStateCached"
  end
  if joined:find("MARKED", 1, true) then
    return "ThemeBrowserStateMarked"
  end
  return "ThemeBrowserStateAvailable"
end

function M.render(session, state_mod, set_cursor_to_selected)
  if not session.bufnr or not vim.api.nvim_buf_is_valid(session.bufnr) then
    return
  end

  session.is_rendering = true

  local state = require("theme-browser.persistence.state")
  local lines = {}
  local line_meta = {}
  local snapshot = type(state.build_state_snapshot) == "function" and state.build_state_snapshot() or nil

  local name_width = 20
  local variant_width = 18
  for _, entry in ipairs(session.filtered_entries) do
    local variant = entry.variant or "default"
    name_width = math.max(name_width, #entry.name)
    variant_width = math.max(variant_width, #variant)
  end
  name_width = math.min(name_width + 2, 32)
  variant_width = math.min(variant_width + 2, 32)

  if #session.filtered_entries == 0 then
    session.row_offset = 0
    table.insert(lines, "No themes found")
    table.insert(lines, "Try: /name, /variant, /repo")
    session.selected_idx = 1
  else
    session.row_offset = 2
    table.insert(lines, fit("Theme", name_width) .. " " .. fit("Variant", variant_width) .. " State")
    table.insert(lines, string.rep("-", name_width) .. " " .. string.rep("-", variant_width) .. " " .. string.rep("-", 18))

    for _, entry in ipairs(session.filtered_entries) do
      local variant = entry.variant or "default"
      local states = state_labels.format_readable_states(state, entry, snapshot)
      local badges, tokens = format_state_badges(states)
      local state_col = name_width + variant_width + 2
      local line = string.format("%s %s %s", fit(entry.name, name_width), fit(variant, variant_width), badges)
      table.insert(lines, line)
      table.insert(line_meta, {
        row = #lines,
        state_col = state_col,
        hl = pick_state_hl(tokens),
      })
    end
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = session.bufnr })
  vim.api.nvim_buf_set_lines(session.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(session.bufnr, session.ns, 0, -1)

  if #session.filtered_entries == 0 then
    if #lines >= 1 then
      vim.api.nvim_buf_add_highlight(session.bufnr, session.ns, "ThemeBrowserHeader", 0, 0, -1)
    end
    if #lines >= 2 then
      vim.api.nvim_buf_add_highlight(session.bufnr, session.ns, "ThemeBrowserSubtle", 1, 0, -1)
    end
  else
    if #lines >= 1 then
      vim.api.nvim_buf_add_highlight(session.bufnr, session.ns, "ThemeBrowserTableHeader", 0, 0, -1)
    end
    if #lines >= 2 then
      vim.api.nvim_buf_add_highlight(session.bufnr, session.ns, "ThemeBrowserDivider", 1, 0, -1)
    end
  end

  for _, meta in ipairs(line_meta) do
    vim.api.nvim_buf_add_highlight(session.bufnr, session.ns, meta.hl, meta.row - 1, meta.state_col, -1)
  end

  if #session.filtered_entries > 0 and session.selected_idx >= 1 and session.selected_idx <= #session.filtered_entries then
    vim.api.nvim_buf_set_extmark(session.bufnr, session.ns, state_mod.index_to_row(session, session.selected_idx) - 1, 0, {
      line_hl_group = "ThemeBrowserRowSelected",
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
