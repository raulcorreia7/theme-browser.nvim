local M = {}

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
