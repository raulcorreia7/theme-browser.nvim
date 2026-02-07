local M = {}

local function entry_id(entry)
  return string.format("%s:%s", entry.name, entry.variant or "")
end

function M.focus_window(session)
  if session.winid and vim.api.nvim_win_is_valid(session.winid) then
    local ok = pcall(vim.api.nvim_set_current_win, session.winid)
    return ok
  end
  return false
end

local function is_entry_locally_available(entry)
  local state = require("theme-browser.persistence.state")
  if type(state.get_entry_state) ~= "function" then
    return false
  end

  local snapshot = type(state.build_state_snapshot) == "function" and state.build_state_snapshot() or nil
  local entry_state = state.get_entry_state(entry, { snapshot = snapshot })
  if type(entry_state) ~= "table" then
    return false
  end

  return entry_state.installed == true or entry_state.cached == true
end

function M.preview_selected_on_move(session, get_selected_entry, get_config)
  local ui = get_config().ui or {}
  if ui.preview_on_move ~= true then
    return
  end

  local entry = get_selected_entry()
  if not entry or not is_entry_locally_available(entry) then
    return
  end

  local current_id = entry_id(entry)
  if session.last_cursor_preview_id == current_id then
    return
  end

  local theme_service = require("theme-browser.application.theme_service")
  theme_service.preview(entry.name, entry.variant, { notify = false })
  session.last_cursor_preview_id = current_id
  M.focus_window(session)
end

function M.apply_selected(session, get_selected_entry, render)
  local entry = get_selected_entry()
  if not entry then
    return
  end

  local theme_service = require("theme-browser.application.theme_service")
  theme_service.apply(entry.name, entry.variant)
  render()
  M.focus_window(session)
end

function M.preview_selected(session, get_selected_entry, render)
  local entry = get_selected_entry()
  if not entry then
    return
  end

  local theme_service = require("theme-browser.application.theme_service")
  theme_service.preview(entry.name, entry.variant)
  render()
  M.focus_window(session)
end

function M.install_selected(session, get_selected_entry, render)
  local entry = get_selected_entry()
  if not entry then
    return
  end

  local theme_service = require("theme-browser.application.theme_service")
  theme_service.install(entry.name, entry.variant)
  render()
  M.focus_window(session)
end

function M.mark_selected(session, get_selected_entry, render)
  local entry = get_selected_entry()
  if not entry then
    return
  end

  local state = require("theme-browser.persistence.state")
  state.mark_theme(entry.name, entry.variant)
  render()
  M.focus_window(session)
end

return M
