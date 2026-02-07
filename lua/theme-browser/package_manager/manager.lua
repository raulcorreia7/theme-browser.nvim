local M = {}

local pending_callbacks = {}
local hooks_registered = false
local valid_modes = {
  auto = true,
  manual = true,
  plugin_only = true,
}

local function normalize_mode(mode)
  if type(mode) ~= "string" then
    return "plugin_only"
  end
  if valid_modes[mode] then
    return mode
  end
  return "plugin_only"
end

local function safe_require(name)
  local ok, mod = pcall(require, name)
  if ok then
    return mod
  end
  return nil
end

function M.get_config()
  local state = safe_require("theme-browser.persistence.state")
  if not state or type(state.get_package_manager) ~= "function" then
    return { enabled = false, mode = "plugin_only" }
  end

  local pm = state.get_package_manager() or {}
  return {
    enabled = pm.enabled == true,
    mode = normalize_mode(pm.mode),
  }
end

function M.is_available()
  return package.loaded["lazy"] ~= nil or pcall(require, "lazy")
end

function M.is_managed()
  local cfg = M.get_config()
  local managed_mode = cfg.mode == "auto" or cfg.mode == "manual"
  return cfg.enabled and managed_mode and M.is_available()
end

function M.can_delegate_load()
  local cfg = M.get_config()
  return cfg.enabled and cfg.mode == "auto" and M.is_available()
end

function M.is_ready()
  if M.is_managed() then
    return vim.v.vim_did_enter == 1
  end
  return true
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

  if not M.can_delegate_load() then
    return false
  end

  local lazy = safe_require("lazy")
  if not lazy or type(lazy.load) ~= "function" then
    return false
  end

  pcall(lazy.load, {
    plugins = { entry.repo, entry.name },
  })
  return true
end

function M.load_theme(theme_name, variant)
  local registry = safe_require("theme-browser.adapters.registry")
  if not registry or type(registry.resolve) ~= "function" then
    return false
  end
  local entry = registry.resolve(theme_name, variant)
  return M.load_entry(entry)
end

return M
