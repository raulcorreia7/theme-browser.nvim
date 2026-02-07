local M = {}

local log = require("theme-browser.util.log")
local package_manager = require("theme-browser.package_manager.manager")
local runtime_loader = require("theme-browser.runtime.loader")
local startup_persistence = require("theme-browser.startup.persistence")

local function get_state_module()
  local ok, state = pcall(require, "theme-browser.persistence.state")
  if ok then
    return state
  end
  return nil
end

local function save_current_theme(name, variant)
  local state = get_state_module()
  if not state or type(state.set_current_theme) ~= "function" then
    return
  end
  state.set_current_theme(name, variant)
end

local function maybe_notify(level, message, opts)
  local notify_enabled = opts.notify
  if notify_enabled == nil then
    notify_enabled = true
  end
  if notify_enabled then
    log.notify(level, message)
  end
end

local function canonical_theme_ref(theme_name, variant)
  local ok_registry, registry = pcall(require, "theme-browser.adapters.registry")
  if not ok_registry or type(registry.resolve) ~= "function" then
    return theme_name, variant
  end

  local entry = registry.resolve(theme_name, variant)
  if not entry then
    return theme_name, variant
  end

  return entry.name or theme_name, entry.variant
end

local function persist_applied_theme(result, opts, current_theme)
  if opts.preview then
    return
  end

  local current_name = result.name
  local current_variant = result.variant
  if type(current_theme) == "table" then
    current_name = current_theme.name or current_name
    current_variant = current_theme.variant
  end

  save_current_theme(current_name, current_variant)

  startup_persistence.persist_applied_theme(result.name, result.variant, result.colorscheme, opts)
end

local function pending_result(theme_name, variant, result)
  return {
    ok = false,
    pending = true,
    name = theme_name,
    variant = variant,
    colorscheme = nil,
    strategy = result.strategy,
    errors = result.errors,
  }
end

---Detect if package manager (lazy.nvim) is available
---@return boolean
function M.has_package_manager()
  return package_manager.is_available()
end

---Get theme status for gallery display
---@param theme_name string
---@return table {installed: boolean, variants: string[]|nil}
function M.get_status(theme_name)
  local factory = require("theme-browser.adapters.factory")
  return factory.get_theme_status(theme_name)
end

---Load a theme
---@param theme_name string
---@param variant string|nil
---@param opts table|nil
---@return table
function M.load_theme(theme_name, variant, opts)
  opts = opts or {}
  local current_theme = nil

  local factory = require("theme-browser.adapters.factory")
  local result = factory.load_theme(theme_name, variant, opts)

  if (not opts.preview) and package_manager.is_managed() then
    local canonical_name, canonical_variant = canonical_theme_ref(theme_name, variant)
    current_theme = { name = canonical_name, variant = canonical_variant }

    if not result.ok then
      package_manager.load_theme(theme_name, variant)
      result = factory.load_theme(theme_name, variant, opts)
    end
  end

  if result.ok then
    persist_applied_theme(result, opts, current_theme)
    local mode = opts.preview and "Preview" or "Theme"
    maybe_notify(vim.log.levels.INFO, string.format("%s applied: %s", mode, result.colorscheme or result.name), opts)
    return result
  end

  local reason = result.errors and (result.errors.colorscheme_error or result.errors.not_found) or "unknown error"
  if opts.preview then
    maybe_notify(vim.log.levels.WARN, string.format("Failed to load '%s': %s", theme_name, reason), opts)
    return result
  end

  runtime_loader.ensure_available(theme_name, variant, {
    notify = opts.notify,
    reason = "apply",
  }, function(success, err)
    if not success then
      maybe_notify(vim.log.levels.WARN, string.format("Failed to load '%s': %s", theme_name, err or reason), opts)
      return
    end

    local retry = factory.load_theme(theme_name, variant, opts)
    if retry.ok then
      persist_applied_theme(retry, opts, current_theme)
      maybe_notify(vim.log.levels.INFO, string.format("Theme applied: %s", retry.colorscheme or retry.name), opts)
      return
    end

    local retry_reason = retry.errors and (retry.errors.colorscheme_error or retry.errors.not_found) or "unknown error"
    maybe_notify(vim.log.levels.WARN, string.format("Failed to load '%s': %s", theme_name, retry_reason), opts)
  end)

  return pending_result(theme_name, variant, result)
end

return M
