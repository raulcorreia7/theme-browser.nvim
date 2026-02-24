local M = {}

local startup_config = require("theme-browser.startup.config")

local function target_colorscheme(entry, startup_theme)
  if type(startup_theme) == "table" and type(startup_theme.colorscheme) == "string" and startup_theme.colorscheme ~= "" then
    return startup_theme.colorscheme
  end

  if type(entry) == "table" and type(entry.colorscheme) == "string" and entry.colorscheme ~= "" then
    return entry.colorscheme
  end

  if type(entry) == "table" and type(entry.name) == "string" then
    return entry.name
  end

  return nil
end

local function apply_entry(entry)
  local ok_base, base = pcall(require, "theme-browser.adapters.base")
  if not ok_base or type(base.load_theme) ~= "function" then
    return false
  end

  local result = base.load_theme(entry.name, entry.variant, { notify = false, persist_startup = false })
  return type(result) == "table" and result.ok == true
end

---@param config table
---@param state table
---@param entry table
---@return boolean
function M.should_skip(config, state, entry)
  local startup = startup_config.resolve(config)
  if not startup.skip_if_already_active then
    return false
  end

  local startup_theme = type(state.get_startup_theme) == "function" and state.get_startup_theme() or nil
  local target = target_colorscheme(entry, startup_theme)
  if type(target) ~= "string" or target == "" then
    return false
  end

  return vim.g.colors_name == target
end

---@param config table
---@param state table
---@param registry table
---@return boolean
function M.restore_current_theme(config, state, registry)
  if type(state) ~= "table" or type(registry) ~= "table" or type(registry.resolve) ~= "function" then
    return false
  end

  local current = type(state.get_current_theme) == "function" and state.get_current_theme() or nil
  if type(current) ~= "table" or type(current.name) ~= "string" then
    return false
  end

  local entry = registry.resolve(current.name, current.variant)
  if not entry then
    return false
  end

  if M.should_skip(config, state, entry) then
    return false
  end

  local success = apply_entry(entry)
  if success and type(state.set_browser_enabled) == "function" then
    state.set_browser_enabled(true)
  end

  return success
end

return M
