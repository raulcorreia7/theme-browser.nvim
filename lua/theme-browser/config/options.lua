local M = {}

local function matches_type(value, type_string)
  if type_string:find("|", 1, true) then
    for _, part in ipairs(vim.split(type_string, "|", { plain = true })) do
      if part == "nil" and value == nil then
        return true
      end
      if part ~= "nil" and type(value) == part then
        return true
      end
    end
    return false
  end

  return type(value) == type_string
end

---@class Config
---@field registry_path string?
---@field cache_dir string?
---@field default_theme string?
---@field auto_load boolean?
---@field startup table?
---@field cache table?
---@field show_preview boolean?
---@field keymaps table?
---@field status_display table?
---@field ui table?
---@field package_manager table?

---@type Config
local schema = {
  registry_path = "string",
  cache_dir = "string",
  default_theme = "string|nil",
  auto_load = "boolean",
  startup = "table",
  cache = "table",
  show_preview = "boolean",
  log_level = "string",
  package_manager = "table",
  ui = "table",
  status_display = "table",
  keymaps = "table",
}

local defaults = require("theme-browser.config.defaults")

function M.validate(user_config)
  if not user_config then
    return vim.deepcopy(defaults)
  end

  local validated = vim.deepcopy(defaults)

  for key, value in pairs(user_config) do
    if schema[key] == nil then
      vim.notify(string.format("Unknown config option: %s", key), vim.log.levels.WARN)
    elseif not matches_type(value, schema[key]) then
      vim.notify(
        string.format("Invalid type for %s: expected %s, got %s", key, schema[key], type(value)),
        vim.log.levels.ERROR
      )
    else
      validated[key] = value
    end
  end

  return validated
end

function M.get_expected_type(type_string)
  return type_string
end

return M
