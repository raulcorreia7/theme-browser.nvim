local M = {}

local ICONS = {
  current = "●",
  installed = "◆",
  dark = "◐",
  light = "◑",
  available = "○",
  marked = "★",
}

local function has_nerd_font()
  local g = vim.g
  return g.have_nerd_font == true or g.have_nerd_font == 1 or g.NerdFont == true
end

if has_nerd_font() then
  ICONS.current = ""
  ICONS.installed = ""
  ICONS.dark = ""
  ICONS.light = ""
  ICONS.available = ""
  ICONS.marked = ""
end

function M.get_icons()
  return ICONS
end

---@param state table
---@param entry table
---@param snapshot table|nil
---@return table {icon: string, states: string[], mode: string|nil}
function M.get_entry_display(state, entry, snapshot)
  if type(state.get_entry_state) ~= "function" then
    return {
      icon = ICONS.available,
      states = { "available" },
      mode = entry.mode,
    }
  end

  local entry_state = state.get_entry_state(entry, { snapshot = snapshot })
  local states = {}
  local mode = entry.mode

  if entry_state.active then
    table.insert(states, "current")
  elseif entry_state.installed then
    table.insert(states, "installed")
  else
    table.insert(states, "available")
  end

  if entry_state.marked then
    table.insert(states, "marked")
  end

  local icon
  if entry_state.active then
    icon = ICONS.current
  elseif entry_state.installed then
    icon = ICONS.installed
  else
    icon = ICONS.available
  end

  return {
    icon = icon,
    states = states,
    mode = mode,
  }
end

---@param state table
---@param entry table
---@param snapshot table|nil
---@return string
function M.format_readable_states(state, entry, snapshot)
  if type(state.get_entry_state) ~= "function" then
    if type(state.format_entry_states) == "function" then
      return state.format_entry_states(entry, { all = false, pretty = false })
    end
    return "Available"
  end

  local entry_state = state.get_entry_state(entry, { snapshot = snapshot })
  local labels = {}

  if entry_state.active then
    table.insert(labels, "Current")
  end
  if entry_state.installed then
    table.insert(labels, "Installed")
  end
  if entry_state.cached then
    table.insert(labels, "Downloaded")
  end
  if entry_state.marked then
    table.insert(labels, "Marked")
  end

  if #labels == 0 then
    return "Available"
  end

  return table.concat(labels, ", ")
end

return M
