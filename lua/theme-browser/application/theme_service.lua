local M = {}

local base = require("theme-browser.adapters.base")
local log = require("theme-browser.util.log")

local function maybe_cleanup_preview(opts)
  if opts and opts.cleanup_preview == false then
    return
  end

  local ok, preview = pcall(require, "theme-browser.preview.manager")
  if ok and type(preview.cleanup) == "function" then
    preview.cleanup()
  end
end

local function resolve_cache_dir()
  local ok_tb, tb = pcall(require, "theme-browser")
  if ok_tb and type(tb.get_config) == "function" then
    local config = tb.get_config()
    if type(config) == "table" and type(config.cache_dir) == "string" and config.cache_dir ~= "" then
      return config.cache_dir
    end
  end
  return vim.fn.stdpath("cache") .. "/theme-browser"
end

local function get_repo_for_theme(theme_name, variant)
  local ok_reg, registry = pcall(require, "theme-browser.adapters.registry")
  if not ok_reg then
    return nil
  end
  local entry = registry.resolve(theme_name, variant)
  if entry and type(entry.repo) == "string" then
    return entry.repo
  end
  return nil
end

---Apply a theme synchronously without notifications.
---This is an internal helper that wraps base.load_theme.
---@param theme_name string
---@param variant string|nil
---@param opts table|nil
---@return table result with ok, name, variant, colorscheme, errors fields
local function apply_without_notify(theme_name, variant, opts)
  local apply_opts = vim.tbl_extend("force", opts or {}, {
    notify = false,
  })
  return base.load_theme(theme_name, variant, apply_opts)
end

local function can_use_package_manager()
  local ok_pm, package_manager = pcall(require, "theme-browser.package_manager.manager")
  if not ok_pm or type(package_manager.install_theme) ~= "function" then
    return false
  end
  if type(package_manager.can_manage_install) == "function" and not package_manager.can_manage_install(true) then
    return false
  end
  return true
end

local function install_with_package_manager_async(theme_name, variant, opts, callback)
  if opts.install_missing == false then
    callback(false)
    return
  end

  if not can_use_package_manager() then
    callback(false)
    return
  end

  local package_manager = require("theme-browser.package_manager.manager")
  local install_opts = {
    load = false,
    force = true,
    wait = false,
  }

  package_manager.install_theme(theme_name, variant, install_opts)
  vim.schedule(function()
    callback(true)
  end)
end

local function download_with_github_async(theme_name, variant, opts, callback)
  local repo = get_repo_for_theme(theme_name, variant)
  if not repo then
    callback(false, "theme not found in registry")
    return
  end

  local cache_dir = resolve_cache_dir()
  local github = require("theme-browser.downloader.github")

  github.download(repo, cache_dir, function(success, err)
    vim.schedule(function()
      if success then
        callback(true, nil)
      else
        callback(false, err or "download failed")
      end
    end)
  end, {
    notify = opts.notify ~= false,
    title = opts.title or "Theme Browser",
  })
end

local function ensure_theme_available_async(theme_name, variant, opts, callback)
  local initial = apply_without_notify(theme_name, variant, opts)
  if initial and initial.ok then
    callback(true, nil, initial)
    return
  end

  if can_use_package_manager() then
    install_with_package_manager_async(theme_name, variant, opts, function(pm_success)
      if pm_success then
        local loader = require("theme-browser.runtime.loader")
        loader.attach_cached_runtime(theme_name, variant)
        local result = apply_without_notify(theme_name, variant, opts)
        if result and result.ok then
          callback(true, nil, result)
          return
        end
      end

      download_with_github_async(theme_name, variant, opts, function(dl_success, dl_err)
        if not dl_success then
          callback(false, dl_err or "theme unavailable", initial)
          return
        end

        local loader = require("theme-browser.runtime.loader")
        local ok_attach, attach_err = loader.attach_cached_runtime(theme_name, variant)
        if not ok_attach then
          callback(false, attach_err or "failed to attach runtime", initial)
          return
        end

        local result = apply_without_notify(theme_name, variant, opts)
        callback(result and result.ok, result and result.errors and result.errors.colorscheme_error, result)
      end)
    end)
  else
    download_with_github_async(theme_name, variant, opts, function(dl_success, dl_err)
      if not dl_success then
        callback(false, dl_err or "theme unavailable", initial)
        return
      end

      local loader = require("theme-browser.runtime.loader")
      local ok_attach, attach_err = loader.attach_cached_runtime(theme_name, variant)
      if not ok_attach then
        callback(false, attach_err or "failed to attach runtime", initial)
        return
      end

      local result = apply_without_notify(theme_name, variant, opts)
      callback(result and result.ok, result and result.errors and result.errors.colorscheme_error, result)
    end)
  end
end

local function ensure_managed_spec(theme_name, variant)
  local ok_spec, lazy_spec = pcall(require, "theme-browser.persistence.lazy_spec")
  if not ok_spec or type(lazy_spec.generate_spec) ~= "function" then
    return nil
  end

  return lazy_spec.generate_spec(theme_name, variant, {
    notify = false,
    update_state = false,
  })
end

---Apply a theme synchronously.
---This function applies the theme immediately. It does not handle installation.
---For automatic installation of missing themes, use M.use_async() instead.
---
---@param theme_name string
---@param variant string|nil
---@param opts table|nil Options table
---@return table result with ok, name, variant, colorscheme, errors fields
function M.apply(theme_name, variant, opts)
  opts = opts or {}
  maybe_cleanup_preview(opts)
  return base.load_theme(theme_name, variant, opts)
end

---Use a theme asynchronously, installing/downloading it if necessary.
---First attempts to apply the theme. If that fails (theme not installed),
---it installs via package manager or downloads from GitHub, then applies.
---
---ASYNC: Always non-blocking. Returns immediately with async_pending=true.
---Use callback to know when the operation completes.
---
---@param theme_name string
---@param variant string|nil
---@param opts table|nil Options table
---@param callback function|nil Called with (success:boolean, result:table|nil, err:string|nil)
---@return table result with async_pending=true to indicate background operation
function M.use(theme_name, variant, opts, callback)
  opts = opts or {}
  maybe_cleanup_preview(opts)

  local initial = apply_without_notify(theme_name, variant, opts)
  if initial and initial.ok then
    if opts.notify ~= false then
      log.info(string.format("Theme applied: %s", initial.colorscheme or initial.name or theme_name))
    end
    if type(callback) == "function" then
      callback(true, initial, nil)
    end
    return initial
  end

  ensure_managed_spec(theme_name, variant)

  if opts.notify ~= false then
    log.info(string.format("Installing theme '%s'...", theme_name))
  end

  ensure_theme_available_async(theme_name, variant, opts, function(success, err, result)
    vim.schedule(function()
      if success and result and result.ok then
        if opts.notify ~= false then
          log.info(string.format("Theme applied: %s", result.colorscheme or result.name or theme_name))
        end
        if type(callback) == "function" then
          callback(true, result, nil)
        end
      else
        local reason = err or (result and result.errors and (result.errors.runtime_error or result.errors.colorscheme_error)) or "theme unavailable"
        if opts.notify ~= false then
          log.warn(string.format("Unable to use '%s': %s", theme_name, reason))
        end
        if type(callback) == "function" then
          callback(false, result or initial, reason)
        end
      end
    end)
  end)

  return {
    ok = true,
    async_pending = true,
    name = theme_name,
    variant = variant,
    message = string.format("Theme '%s' is being installed in background", theme_name),
  }
end

---Apply a theme for preview (internal helper).
---@param theme_name string
---@param variant string|nil
---@param opts table|nil
---@return table result with ok, name, variant, colorscheme, errors fields
local function apply_preview(theme_name, variant, opts)
  local preview_opts = vim.tbl_extend("force", opts or {}, {
    preview = true,
    notify = false,
  })
  return base.load_theme(theme_name, variant, preview_opts)
end

---Preview a theme asynchronously without persisting it as the current selection.
---
---ASYNC: Always non-blocking. Returns immediately with status 0 to indicate initiated.
---Use callbacks to know when the preview is actually applied.
---
---@param theme_name string
---@param variant string|nil
---@param opts table|nil Options table
---@return number status 0 on initiated, 1 on immediate failure
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

  if opts.notify ~= false then
    log.info(string.format("Installing theme '%s' for preview...", theme_name))
  end

  local preview_opts = vim.tbl_extend("force", opts, {
    preview = true,
    notify = false,
  })

  ensure_theme_available_async(theme_name, variant, preview_opts, function(success, err, result)
    vim.schedule(function()
      if success and result and result.ok then
        if type(opts.on_preview_applied) == "function" then
          opts.on_preview_applied(theme_name, variant)
        end
        if opts.notify ~= false then
          log.info(string.format("Preview applied: %s", result.colorscheme or result.name or theme_name))
        end
      else
        local reason = err or (result and result.errors and (result.errors.colorscheme_error or result.errors.runtime_error)) or "theme unavailable"
        if opts.notify ~= false then
          log.warn(string.format("Preview failed: %s", reason))
        end
      end
    end)
  end)

  return 0
end

---Install a theme asynchronously (alias for use()).
---
---ASYNC: Always non-blocking. Use callback to know when complete.
---
---@param theme_name string
---@param variant string|nil
---@param opts table|nil Options table
---@param callback function|nil Called with (success:boolean, result:table|nil, err:string|nil)
---@return table result with async_pending=true
function M.install(theme_name, variant, opts, callback)
  return M.use(theme_name, variant, opts, callback)
end

return M
