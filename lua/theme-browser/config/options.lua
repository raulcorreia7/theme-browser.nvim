local M = {}

local defaults = require("theme-browser.config.defaults")

local scalar_schema = {
  registry_path = "string",
  cache_dir = "string",
  auto_load = "boolean",
  log_level = "string",
}

local nested_schema = {
  startup = {
    enabled = "boolean",
    write_spec = "boolean",
    skip_if_already_active = "boolean",
  },
  cache = {
    auto_cleanup = "boolean",
    cleanup_interval_days = "number",
  },
  ui = {
    window_width = "number",
    window_height = "number",
    border = "string",
    show_hints = "boolean",
    show_breadcrumbs = "boolean",
    preview_on_move = "boolean",
  },
  package_manager = {
    enabled = "boolean",
    mode = "string",
    provider = "string",
  },
  keymaps = {
    close = "table|string",
    select = "table|string",
    preview = "table|string",
    install = "table|string",
    set_main = "table|string",
    navigate_up = "table|string",
    navigate_down = "table|string",
    goto_top = "table|string",
    goto_bottom = "table|string",
    search = "table|string",
    clear_search = "table|string",
    copy_repo = "table|string",
    open_repo = "table|string",
  },
  status_display = {
    show_adapter = "boolean",
    show_repo = "boolean",
    show_cache_stats = "boolean",
  },
}

local top_level_order = {
  "registry_path",
  "cache_dir",
  "auto_load",
  "log_level",
  "startup",
  "cache",
  "ui",
  "package_manager",
  "keymaps",
  "status_display",
}

local removed_top_level_hints = {
  show_preview = "use ui.preview_on_move",
}

local log_levels = {
  error = true,
  warn = true,
  info = true,
  debug = true,
}

local package_manager_modes = {
  auto = true,
  manual = true,
  installed_only = true,
}

local package_manager_providers = {
  auto = true,
  lazy = true,
  noop = true,
}

local function notify_warn(message)
  vim.notify(message, vim.log.levels.WARN)
end

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

local function sorted_keys(tbl)
  local keys = {}
  for key in pairs(tbl) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

local function normalize_keymap_list(value, default_value, keypath)
  if type(value) == "string" then
    if value == "" then
      notify_warn(string.format("Invalid empty keymap for %s; keeping default", keypath))
      return default_value
    end
    return { value }
  end

  if type(value) ~= "table" then
    notify_warn(string.format("Invalid type for %s: expected table|string, got %s", keypath, type(value)))
    return default_value
  end

  local normalized = {}
  for _, item in ipairs(value) do
    if type(item) == "string" and item ~= "" then
      table.insert(normalized, item)
    else
      notify_warn(string.format("Invalid keymap entry for %s; keeping default", keypath))
      return default_value
    end
  end

  if #normalized == 0 then
    notify_warn(string.format("Invalid empty keymap list for %s; keeping default", keypath))
    return default_value
  end

  return normalized
end

local function validate_nested_value(parent_key, key, value, default_value)
  local keypath = string.format("%s.%s", parent_key, key)

  if parent_key == "cache" and key == "cleanup_interval_days" then
    if type(value) ~= "number" or value < 1 then
      notify_warn(string.format("Invalid value for %s: expected number >= 1; keeping default", keypath))
      return default_value
    end
    return math.floor(value)
  end

  if parent_key == "ui" and (key == "window_width" or key == "window_height") then
    if type(value) ~= "number" or value <= 0 or value > 1 then
      notify_warn(string.format("Invalid value for %s: expected number in (0, 1]; keeping default", keypath))
      return default_value
    end
    return value
  end

  if parent_key == "package_manager" and key == "mode" then
    if type(value) ~= "string" or not package_manager_modes[value] then
      notify_warn(
        string.format("Invalid value for %s: expected auto|manual|installed_only; keeping default", keypath)
      )
      return default_value
    end
    return value
  end

  if parent_key == "package_manager" and key == "provider" then
    if type(value) ~= "string" or not package_manager_providers[value] then
      notify_warn(string.format("Invalid value for %s: expected auto|lazy|noop; keeping default", keypath))
      return default_value
    end
    return value
  end

  if parent_key == "keymaps" then
    return normalize_keymap_list(value, default_value, keypath)
  end

  return value
end

local function normalize_nested(parent_key, user_value, default_value)
  if type(user_value) ~= "table" then
    notify_warn(string.format("Invalid type for %s: expected table, got %s", parent_key, type(user_value)))
    return vim.deepcopy(default_value)
  end

  local schema = nested_schema[parent_key] or {}
  local normalized = vim.deepcopy(default_value)

  for _, key in ipairs(sorted_keys(user_value)) do
    if schema[key] == nil then
      notify_warn(string.format("Unknown config option: %s.%s", parent_key, key))
    end
  end

  for _, key in ipairs(sorted_keys(schema)) do
    local value = user_value[key]
    if value ~= nil then
      if not matches_type(value, schema[key]) then
        notify_warn(
          string.format(
            "Invalid type for %s.%s: expected %s, got %s",
            parent_key,
            key,
            schema[key],
            type(value)
          )
        )
      else
        normalized[key] = validate_nested_value(parent_key, key, value, default_value[key])
      end
    end
  end

  return normalized
end

---@param user_config table|nil
---@return table
function M.validate(user_config)
  local validated = vim.deepcopy(defaults)

  if user_config == nil then
    return validated
  end

  if type(user_config) ~= "table" then
    notify_warn(string.format("Invalid config type: expected table, got %s", type(user_config)))
    return validated
  end

  local known_top_level = {}
  for _, key in ipairs(top_level_order) do
    known_top_level[key] = true
  end

  for _, key in ipairs(sorted_keys(user_config)) do
    if not known_top_level[key] then
      local hint = removed_top_level_hints[key]
      if hint then
        notify_warn(string.format("Unknown config option: %s (%s)", key, hint))
      else
        notify_warn(string.format("Unknown config option: %s", key))
      end
    end
  end

  for _, key in ipairs(top_level_order) do
    local value = user_config[key]
    if value ~= nil then
      if scalar_schema[key] then
        if not matches_type(value, scalar_schema[key]) then
          notify_warn(
            string.format("Invalid type for %s: expected %s, got %s", key, scalar_schema[key], type(value))
          )
        else
          validated[key] = value
        end
      elseif nested_schema[key] then
        validated[key] = normalize_nested(key, value, defaults[key])
      end
    end
  end

  if type(validated.log_level) ~= "string" or not log_levels[validated.log_level] then
    notify_warn("Invalid value for log_level: expected error|warn|info|debug; keeping default")
    validated.log_level = defaults.log_level
  end

  return validated
end

return M
