local M = {}

local state = require("theme-browser.persistence.state")

function M.entry_background(entry)
  local meta = entry.meta or {}
  if meta.background == "light" or meta.background == "dark" then
    return meta.background
  end
  if
    type(meta.opts_o) == "table" and (meta.opts_o.background == "light" or meta.opts_o.background == "dark")
  then
    return meta.opts_o.background
  end
  if entry.mode == "light" or entry.mode == "dark" then
    return entry.mode
  end
  return "dark"
end

function M.entry_status(entry, snapshot)
  local current = state.get_current_theme()
  if current and current.name == entry.name and (current.variant or "") == (entry.variant or "") then
    return "current"
  end

  local entry_state = state.get_entry_state(entry, { snapshot = snapshot }) or {}
  if entry_state.installed then
    return "installed"
  end
  if entry_state.cached then
    return "downloaded"
  end
  return "available"
end

return M
