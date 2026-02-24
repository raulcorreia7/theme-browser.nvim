local M = {}

local pending_callbacks = {}
local hooks_registered = false

local function safe_require(name)
  local ok, mod = pcall(require, name)
  if ok then
    return mod
  end
  return nil
end

local function flush_callbacks()
  if #pending_callbacks == 0 then
    return
  end

  local callbacks = pending_callbacks
  pending_callbacks = {}
  for _, callback in ipairs(callbacks) do
    vim.schedule(callback)
  end
end

local function register_ready_hooks()
  if hooks_registered then
    return
  end
  hooks_registered = true

  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = flush_callbacks,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      vim.defer_fn(flush_callbacks, 100)
    end,
  })
end

local function resolve_plugins(entry)
  local function is_repo_ref(value)
    return type(value) == "string" and value:match("^[^/]+/[^/]+$") ~= nil
  end

  local function push_unique(list, seen, value)
    if type(value) ~= "string" or value == "" or seen[value] then
      return
    end
    seen[value] = true
    table.insert(list, value)
  end

  local plugin_refs = {}
  local seen = {}
  local repo_name = nil

  if type(entry.repo) == "string" and entry.repo ~= "" then
    push_unique(plugin_refs, seen, entry.repo)
    local _, extracted = entry.repo:match("([^/]+)/(.+)")
    repo_name = extracted
  end

  local entry_name = type(entry.name) == "string" and entry.name or nil
  if is_repo_ref(entry_name) then
    push_unique(plugin_refs, seen, entry_name)
  end

  local config = safe_require("lazy.core.config")
  if not config or type(config.plugins) ~= "table" then
    return plugin_refs
  end

  local resolved = {}

  if type(entry.repo) == "string" and config.plugins[entry.repo] then
    table.insert(resolved, entry.repo)
  end

  if type(repo_name) == "string" and repo_name ~= "" and config.plugins[repo_name] then
    table.insert(resolved, repo_name)
  end

  if type(entry_name) == "string" and entry_name ~= "" and config.plugins[entry_name] then
    table.insert(resolved, entry_name)
  end

  if #resolved > 0 then
    return resolved
  end

  return plugin_refs
end

local function reload_specs()
  local reloader = safe_require("lazy.manage.reloader")
  if not reloader or type(reloader.check) ~= "function" then
    return
  end

  pcall(reloader.check, false)
end

function M.id()
  return "lazy"
end

function M.is_available()
  return package.loaded["lazy"] ~= nil or pcall(require, "lazy")
end

function M.is_ready()
  return vim.v.vim_did_enter == 1
end

function M.when_ready(callback)
  if type(callback) ~= "function" then
    return
  end

  if M.is_ready() then
    vim.schedule(callback)
    return
  end

  table.insert(pending_callbacks, callback)
  register_ready_hooks()
end

function M.load_entry(entry)
  if not entry or type(entry.repo) ~= "string" or entry.repo == "" then
    return false
  end

  local lazy = safe_require("lazy")
  if not lazy or type(lazy.load) ~= "function" then
    return false
  end

  local plugins = resolve_plugins(entry)
  if #plugins == 0 then
    return false
  end

  pcall(lazy.load, { plugins = plugins })
  return true
end

function M.install_entry(entry, opts)
  opts = opts or {}

  if not entry or type(entry.repo) ~= "string" or entry.repo == "" then
    return false
  end

  local lazy = safe_require("lazy")
  if not lazy or type(lazy.install) ~= "function" then
    return false
  end

  reload_specs()
  local plugins = resolve_plugins(entry)
  if #plugins == 0 then
    return false
  end

  pcall(lazy.install, {
    plugins = plugins,
    wait = opts.wait == true,
    show = false,
  })

  if opts.load ~= false and type(lazy.load) == "function" then
    pcall(lazy.load, {
      plugins = plugins,
      wait = opts.wait == true,
    })
  end

  return true
end

return M
