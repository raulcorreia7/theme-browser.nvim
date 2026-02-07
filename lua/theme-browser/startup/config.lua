local M = {}

local defaults = {
  enabled = true,
  write_spec = false,
  skip_if_already_active = true,
}

local function read_bool(value, fallback)
  if value == nil then
    return fallback
  end
  return value == true
end

---@param config table|nil
---@return table {enabled:boolean, write_spec:boolean, skip_if_already_active:boolean}
function M.resolve(config)
  local startup = type(config) == "table" and config.startup or nil
  if type(startup) ~= "table" then
    startup = {}
  end

  return {
    enabled = read_bool(startup.enabled, defaults.enabled),
    write_spec = read_bool(startup.write_spec, defaults.write_spec),
    skip_if_already_active = read_bool(startup.skip_if_already_active, defaults.skip_if_already_active),
  }
end

---@return table {enabled:boolean, write_spec:boolean, skip_if_already_active:boolean}
function M.from_runtime()
  local ok, theme_browser = pcall(require, "theme-browser")
  if not ok or type(theme_browser.get_config) ~= "function" then
    return M.resolve(nil)
  end

  return M.resolve(theme_browser.get_config())
end

return M
