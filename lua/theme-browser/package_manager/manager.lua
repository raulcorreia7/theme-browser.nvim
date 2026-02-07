local M = {}

local valid_modes = {
  auto = true,
  manual = true,
  plugin_only = true,
}
local valid_providers = {
  auto = true,
  lazy = true,
  noop = true,
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

local function normalize_provider(provider)
  if type(provider) ~= "string" then
    return "auto"
  end
  if valid_providers[provider] then
    return provider
  end
  return "auto"
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
    return { enabled = false, mode = "plugin_only", provider = "auto" }
  end

  local pm = state.get_package_manager() or {}
  return {
    enabled = pm.enabled == true,
    mode = normalize_mode(pm.mode),
    provider = normalize_provider(pm.provider),
  }
end

local function get_noop_provider()
  local provider = safe_require("theme-browser.package_manager.providers.noop")
  if provider then
    return provider
  end

  return {
    id = function()
      return "noop"
    end,
    is_available = function()
      return false
    end,
    is_ready = function()
      return true
    end,
    when_ready = function(callback)
      if type(callback) == "function" then
        vim.schedule(callback)
      end
    end,
    load_entry = function()
      return false
    end,
    install_entry = function()
      return false
    end,
  }
end

local function resolve_provider(config)
  local cfg = config or M.get_config()
  local provider_name = cfg.provider
  local noop_provider = get_noop_provider()

  if provider_name == "noop" then
    return noop_provider
  end

  if provider_name == "lazy" then
    local lazy_provider = safe_require("theme-browser.package_manager.providers.lazy")
    if lazy_provider and type(lazy_provider.is_available) == "function" and lazy_provider.is_available() then
      return lazy_provider
    end
    return noop_provider
  end

  local lazy_provider = safe_require("theme-browser.package_manager.providers.lazy")
  if lazy_provider and type(lazy_provider.is_available) == "function" and lazy_provider.is_available() then
    return lazy_provider
  end

  return noop_provider
end

function M.get_provider()
  local provider = resolve_provider(M.get_config())
  if type(provider.id) == "function" then
    return provider.id()
  end
  return "unknown"
end

function M.is_available()
  local provider = resolve_provider(M.get_config())
  return type(provider.is_available) == "function" and provider.is_available() == true
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

function M.can_manage_install(force)
  local cfg = M.get_config()
  if force == true then
    return M.is_available()
  end
  return cfg.enabled and cfg.mode ~= "plugin_only" and M.is_available()
end

function M.is_ready()
  if not M.is_managed() then
    return true
  end

  local provider = resolve_provider(M.get_config())
  if type(provider.is_ready) == "function" then
    return provider.is_ready() == true
  end
  return true
end

function M.when_ready(callback)
  if type(callback) ~= "function" then
    return
  end

  if M.is_ready() then
    vim.schedule(callback)
    return
  end

  local provider = resolve_provider(M.get_config())
  if type(provider.when_ready) == "function" then
    provider.when_ready(callback)
    return
  end

  vim.schedule(callback)
end

function M.load_entry(entry)
  if not entry or type(entry.repo) ~= "string" or entry.repo == "" then
    return false
  end

  if not M.can_delegate_load() then
    return false
  end

  local provider = resolve_provider(M.get_config())
  if type(provider.load_entry) ~= "function" then
    return false
  end

  return provider.load_entry(entry) == true
end

function M.load_theme(theme_name, variant)
  local registry = safe_require("theme-browser.adapters.registry")
  if not registry or type(registry.resolve) ~= "function" then
    return false
  end
  local entry = registry.resolve(theme_name, variant)
  return M.load_entry(entry)
end

function M.install_entry(entry, opts)
  opts = opts or {}

  if not entry or type(entry.repo) ~= "string" or entry.repo == "" then
    return false
  end

  if not M.can_manage_install(opts.force == true) then
    return false
  end

  local provider = resolve_provider(M.get_config())
  if type(provider.install_entry) ~= "function" then
    return false
  end

  return provider.install_entry(entry, opts) == true
end

function M.install_theme(theme_name, variant, opts)
  local registry = safe_require("theme-browser.adapters.registry")
  if not registry or type(registry.resolve) ~= "function" then
    return false
  end

  local entry = registry.resolve(theme_name, variant)
  return M.install_entry(entry, opts)
end

return M
