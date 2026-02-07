local M = {}

local base = require("theme-browser.adapters.base")
local log = require("theme-browser.util.log")
local runtime_loader = require("theme-browser.runtime.loader")

local function canonical_theme_reference(theme_name, variant)
  local ok_registry, registry = pcall(require, "theme-browser.adapters.registry")
  if ok_registry and type(registry.resolve) == "function" then
    local entry = registry.resolve(theme_name, variant)
    if entry and type(entry.name) == "string" and entry.name ~= "" then
      return entry.name, entry.variant or variant
    end
  end
  return theme_name, variant
end

local function mark_theme_for_install(theme_name, variant)
  local ok_state, state = pcall(require, "theme-browser.persistence.state")
  if not ok_state or type(state.mark_theme) ~= "function" then
    return
  end

  local canonical_name, canonical_variant = canonical_theme_reference(theme_name, variant)
  state.mark_theme(canonical_name, canonical_variant)
end

local function prefetch_theme(theme_name, variant, opts)
  runtime_loader.ensure_available(theme_name, variant, {
    notify = opts.notify,
    reason = "install",
    allow_package_manager = false,
  }, function(success, err)
    if success or opts.notify == false then
      return
    end
    log.warn(string.format("Background install prefetch failed: %s", err or "unknown error"))
  end)
end

local function load_package_manager_theme(theme_name, variant)
  local ok_pm, package_manager = pcall(require, "theme-browser.package_manager.manager")
  if not ok_pm or type(package_manager.load_theme) ~= "function" then
    return
  end

  if type(package_manager.when_ready) == "function" then
    package_manager.when_ready(function()
      package_manager.load_theme(theme_name, variant)
    end)
    return
  end

  package_manager.load_theme(theme_name, variant)
end

local function start_install_jobs(theme_name, variant, opts)
  if opts.prefetch ~= false then
    prefetch_theme(theme_name, variant, opts)
  end

  if opts.load_package_manager == true then
    load_package_manager_theme(theme_name, variant)
  end
end

local function maybe_cleanup_preview(opts)
  if opts and opts.cleanup_preview == false then
    return
  end

  local ok, preview = pcall(require, "theme-browser.preview.manager")
  if ok and type(preview.cleanup) == "function" then
    preview.cleanup()
  end
end

---@param theme_name string
---@param variant string|nil
---@param opts table|nil
---@return table
function M.apply(theme_name, variant, opts)
  opts = opts or {}
  maybe_cleanup_preview(opts)
  return base.load_theme(theme_name, variant, opts)
end

local function apply_preview(theme_name, variant, opts)
  local preview_opts = vim.tbl_extend("force", opts or {}, {
    preview = true,
    notify = false,
  })
  return base.load_theme(theme_name, variant, preview_opts)
end

---@param theme_name string
---@param variant string|nil
---@param opts table|nil
---@return number
function M.preview(theme_name, variant, opts)
  opts = opts or {}

  local initial = apply_preview(theme_name, variant, opts)
  if initial and initial.ok then
    if type(opts.on_preview_applied) == "function" then
      opts.on_preview_applied(theme_name, variant)
    end
    if opts.notify ~= false then
      log.info(string.format("Preview applied: %s", initial.colorscheme or initial.name or theme_name))
    end
    return 0
  end

  runtime_loader.ensure_available(theme_name, variant, {
    notify = opts.notify,
    reason = "preview",
  }, function(success, err, runtime_path)
    if not success then
      if opts.notify ~= false then
        log.error(string.format("Preview download failed: %s", err or "unknown error"))
      end
      return
    end

    if type(opts.on_runtimepath_added) == "function" and type(runtime_path) == "string" and runtime_path ~= "" then
      opts.on_runtimepath_added(runtime_path)
    end

    local retry = apply_preview(theme_name, variant, opts)
    if retry and retry.ok then
      if type(opts.on_preview_applied) == "function" then
        opts.on_preview_applied(theme_name, variant)
      end
      if opts.notify ~= false then
        log.info(string.format("Preview applied: %s", retry.colorscheme or retry.name or theme_name))
      end
    elseif opts.notify ~= false then
      local reason = retry and retry.errors and retry.errors.colorscheme_error or "unknown error"
      log.warn(string.format("Downloaded, but preview failed: %s", reason))
    end
  end)

  return 0
end

---@param theme_name string
---@param variant string|nil
---@param opts table|nil
---@return string|nil
function M.install(theme_name, variant, opts)
  opts = opts or {}
  maybe_cleanup_preview(opts)
  mark_theme_for_install(theme_name, variant)

  local lazy_spec = require("theme-browser.persistence.lazy_spec")
  local update_current = opts.update_current == true
  local spec_file = lazy_spec.generate_spec(theme_name, variant, {
    notify = opts.notify,
    update_state = update_current,
  })

  local background = opts.background
  if background == nil then
    background = true
  end

  if background then
    vim.schedule(function()
      start_install_jobs(theme_name, variant, opts)
    end)
  else
    start_install_jobs(theme_name, variant, opts)
  end

  return spec_file
end

return M
