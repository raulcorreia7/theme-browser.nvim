local M = {}

local log = require("theme-browser.util.log")
local package_manager = require("theme-browser.package_manager.manager")

local function resolve_entry(theme_name, variant)
  local registry = require("theme-browser.adapters.registry")
  return registry.resolve(theme_name, variant)
end

local function add_to_runtimepath(path)
  if vim.fn.isdirectory(path) == 1 then
    for _, existing in ipairs(vim.opt.runtimepath:get()) do
      if existing == path then
        return true
      end
    end
    vim.opt.runtimepath:prepend(path)
    return true
  end
  return false
end

local function cache_path_for(entry, cache_dir)
  local github = require("theme-browser.downloader.github")
  if type(github.resolve_cache_path) == "function" then
    return github.resolve_cache_path(entry.repo, cache_dir)
  end
  return github.get_cache_path(entry.repo, cache_dir)
end

---@param theme_name string
---@param variant string|nil
---@param opts table|nil {notify:boolean|nil, reason:string|nil, allow_package_manager:boolean|nil}
---@param callback fun(success:boolean, err:string|nil, runtime_path:string|nil)
function M.ensure_available(theme_name, variant, opts, callback)
  opts = opts or {}
  local notify = opts.notify
  if notify == nil then
    notify = true
  end

  local entry = resolve_entry(theme_name, variant)
  if not entry or not entry.repo then
    callback(false, "theme not found in index", nil)
    return
  end

  local allow_package_manager = opts.allow_package_manager ~= false
  if allow_package_manager and type(package_manager.can_delegate_load) == "function" then
    allow_package_manager = package_manager.can_delegate_load()
  end

  if allow_package_manager and package_manager.load_entry(entry) then
    callback(true, nil, nil)
    return
  end

  local config = require("theme-browser").get_config()
  local cache_dir = config.cache_dir
  local github = require("theme-browser.downloader.github")

  if github.is_cached(entry.repo, cache_dir) then
    local runtime_path = cache_path_for(entry, cache_dir)
    local ok = add_to_runtimepath(runtime_path)
    callback(ok, ok and nil or "cached theme path missing", ok and runtime_path or nil)
    return
  end

  if notify then
    local reason = opts.reason or "load"
    log.info(string.format("Downloading %s in background for %s...", entry.repo, reason))
  end

  github.download(entry.repo, cache_dir, function(success, err)
    vim.schedule(function()
      if not success then
        callback(false, err or "download failed", nil)
        return
      end

      local runtime_path = cache_path_for(entry, cache_dir)
      local ok = add_to_runtimepath(runtime_path)
      callback(ok, ok and nil or "downloaded theme path missing", ok and runtime_path or nil)
    end)
  end, { notify = false })
end

return M
