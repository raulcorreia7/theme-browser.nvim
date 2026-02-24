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

---Load a theme synchronously.
---
---SYNC/ASYNC: SYNCHRONOUS - This function blocks until the theme is applied
---or fails. It calls vim.cmd.colorscheme directly. This function does NOT
---handle installation - if the theme is not available, it will fail.
---
---For automatic installation of missing themes, use theme_service.use() instead.
---
---@param theme_name string
---@param variant string|nil
---@param opts table|nil Options table
---   - notify: boolean (default true) - Show notification on success/failure
---   - preview: boolean (default false) - If true, don't persist as current theme
---@return table result with ok, name, variant, colorscheme, errors fields
function M.load_theme(theme_name, variant, opts)
  opts = opts or {}
  local canonical_name, canonical_variant = canonical_theme_ref(theme_name, variant)
  local current_theme = { name = canonical_name, variant = canonical_variant }

  local _, attach_err = runtime_loader.attach_cached_runtime(theme_name, variant)

  local factory = require("theme-browser.adapters.factory")
  local result = factory.load_theme(theme_name, variant, opts)

  if result.ok then
    persist_applied_theme(result, opts, current_theme)
    local mode = opts.preview and "Preview" or "Theme"
    maybe_notify(vim.log.levels.INFO, string.format("%s applied: %s", mode, result.colorscheme or result.name), opts)
    return result
  end

  local reason = result.errors and (result.errors.runtime_error or result.errors.colorscheme_error or result.errors.not_found) or "unknown error"
  if type(result.errors) ~= "table" then
    result.errors = {}
  end
  if attach_err and result.errors.runtime_error == nil then
    result.errors.runtime_error = attach_err
    reason = attach_err
  end

  maybe_notify(vim.log.levels.WARN, string.format("Failed to load '%s': %s", theme_name, reason), opts)
  return result
end

return M
