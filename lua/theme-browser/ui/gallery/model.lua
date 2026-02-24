local M = {}

function M.filter_entries(all_entries, query)
  if not query or query == "" then
    return all_entries
  end

  local lowered = query:lower()
  local filtered = {}

  for _, entry in ipairs(all_entries) do
    local variant = entry.variant or "default"
    local id = string.format("%s:%s", entry.name, variant)

    if entry.name:lower():find(lowered, 1, true)
      or variant:lower():find(lowered, 1, true)
      or (entry.repo and entry.repo:lower():find(lowered, 1, true))
      or id:lower():find(lowered, 1, true)
    then
      table.insert(filtered, entry)
    end
  end

  return filtered
end

function M.sync_selection_to_cursor(session, state_mod, opts, render)
  opts = opts or {}
  if not session.winid or not vim.api.nvim_win_is_valid(session.winid) then
    return false
  end

  if #session.filtered_entries == 0 then
    session.selected_idx = 1
    return false
  end

  local row = vim.api.nvim_win_get_cursor(session.winid)[1]
  local first_row = state_mod.index_to_row(session, 1)
  local last_row = state_mod.index_to_row(session, #session.filtered_entries)
  local changed = false

  if opts.clamp == true and (row < first_row or row > last_row) then
    row = math.max(first_row, math.min(last_row, row))
    pcall(vim.api.nvim_win_set_cursor, session.winid, { row, 0 })
    changed = true
  end

  local line = state_mod.row_to_index(session, row)
  if line >= 1 and line <= #session.filtered_entries and line ~= session.selected_idx then
    session.selected_idx = line
    changed = true
  end

  if changed then
    render()
  end

  return changed
end

function M.get_selected_entry(session, state_mod)
  if session.winid and vim.api.nvim_win_is_valid(session.winid) then
    local cursor = vim.api.nvim_win_get_cursor(session.winid)
    local line = state_mod.row_to_index(session, cursor[1])
    if line >= 1 and line <= #session.filtered_entries then
      session.selected_idx = line
    end
  end

  if session.selected_idx < 1 or session.selected_idx > #session.filtered_entries then
    return nil
  end

  return session.filtered_entries[session.selected_idx]
end

function M.set_cursor_to_selected(session, state_mod)
  if not session.winid or not vim.api.nvim_win_is_valid(session.winid) then
    return
  end

  local line = session.selected_idx
  if line < 1 then
    line = 1
  end

  vim.api.nvim_win_set_cursor(session.winid, { state_mod.index_to_row(session, line), 0 })
end

function M.select_current(session, current)
  if type(current) ~= "table" then
    return
  end

  for idx, entry in ipairs(session.filtered_entries) do
    if entry.name == current.name and (entry.variant or "") == (current.variant or "") then
      session.selected_idx = idx
      return
    end
  end
end

return M
