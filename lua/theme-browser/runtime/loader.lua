local M = {}

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

local function resolve_lazy_install_path(entry)
  if type(entry) ~= "table" or type(entry.repo) ~= "string" then
    return nil
  end

  local _, repo_name = entry.repo:match("([^/]+)/(.+)")
  if type(repo_name) ~= "string" or repo_name == "" then
    return nil
  end

  local lazy_path = vim.fn.stdpath("data") .. "/lazy/" .. repo_name
  if vim.fn.isdirectory(lazy_path) == 1 then
    return lazy_path
  end

  return nil
end

local function cache_path_for(entry, cache_dir)
  local github = require("theme-browser.downloader.github")
  if type(github.resolve_cache_path) == "function" then
    return github.resolve_cache_path(entry.repo, cache_dir)
  end
  return github.get_cache_path(entry.repo, cache_dir)
end

local function resolve_cache_dir()
  local ok_theme_browser, theme_browser = pcall(require, "theme-browser")
  if ok_theme_browser and type(theme_browser.get_config) == "function" then
    local config = theme_browser.get_config()
    if type(config) == "table" and type(config.cache_dir) == "string" and config.cache_dir ~= "" then
      return config.cache_dir
    end
  end

  return vim.fn.stdpath("cache") .. "/theme-browser"
end

---@param theme_name string
---@param variant string|nil
---@return boolean, string|nil, string|nil
function M.attach_cached_runtime(theme_name, variant)
  local entry = resolve_entry(theme_name, variant)
  if not entry or not entry.repo then
    return false, "theme not found in index", nil
  end

  local cache_dir = resolve_cache_dir()
  local runtime_path = cache_path_for(entry, cache_dir)
  if vim.fn.isdirectory(runtime_path) ~= 1 then
    runtime_path = resolve_lazy_install_path(entry)
  end
  if type(runtime_path) ~= "string" or runtime_path == "" then
    return false, "theme is not cached or installed", nil
  end

  local ok = add_to_runtimepath(runtime_path)
  if not ok then
    return false, "theme runtime path missing", nil
  end

  return true, nil, runtime_path
end

---@param theme_name string
---@param variant string|nil
---@param opts table|nil {notify:boolean|nil, reason:string|nil}
---@param callback fun(success:boolean, err:string|nil, runtime_path:string|nil)
function M.ensure_available(theme_name, variant, opts, callback)
  opts = opts or {}
  local _ = opts
  local ok, err, runtime_path = M.attach_cached_runtime(theme_name, variant)
  callback(ok, err, runtime_path)
end

return M
