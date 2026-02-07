local log = require("theme-browser.util.log")
local registry_config = require("theme-browser.config.registry")
local startup_restore = require("theme-browser.startup.restore")

---@class ThemeBrowser
---@field config Config
---@field private initialized boolean

local M = {
  initialized = false,
  config = {},
}

---Validate and normalize user configuration
---@param user_config Config|nil
---@return Config
local function validate_config(user_config)
  local options = require("theme-browser.config.options")
  return options.validate(user_config)
end

local function run_cache_cleanup(force, notify)
  local cache = require("theme-browser.downloader.cache")
  if type(cache.maybe_cleanup) == "function" then
    local ok, reason = cache.maybe_cleanup({ force = force, notify = notify })
    if ok then
      log.info("Theme cache cleaned")
      return
    end
    if reason ~= "not_due" and reason ~= "disabled" then
      log.warn(string.format("Theme cache cleanup failed: %s", reason or "unknown error"))
    end
    return
  end

  cache.clear_all({ notify = notify })
  log.info("Theme cache cleared")
end

local function parse_theme_token(value)
  if type(value) ~= "string" or value == "" then
    return nil, nil
  end

  local name, variant = value:match("^([^:]+):(.+)$")
  if name then
    return name, variant
  end

  return value, nil
end

local function parse_theme_args(args)
  local first = args[1]
  if type(first) ~= "string" or first == "" then
    return nil, nil
  end

  local second = args[2]
  if type(second) == "string" and second ~= "" then
    return first, second
  end

  return parse_theme_token(first)
end

local function ensure_registry_for_completion()
  local ok, registry = pcall(require, "theme-browser.adapters.registry")
  if not ok then
    return nil
  end

  if type(registry.is_initialized) == "function" and not registry.is_initialized() then
    registry.initialize(M.config.registry_path or registry_config.resolve(nil).path)
  end

  return registry
end

local function prefix_match(candidate, lead)
  if type(candidate) ~= "string" then
    return false
  end
  if lead == "" then
    return true
  end

  return candidate:lower():find(lead:lower(), 1, true) == 1
end

local function split_cmd_args(cmdline)
  local trimmed = vim.trim(cmdline)
  local parts = {}
  if trimmed ~= "" then
    parts = vim.split(trimmed, "%s+")
  end

  if #parts > 0 then
    table.remove(parts, 1)
  end

  if cmdline:sub(-1) == " " then
    table.insert(parts, "")
  end

  return parts
end

local function complete_theme_command(arglead, cmdline)
  local registry = ensure_registry_for_completion()
  if not registry then
    return {}
  end

  local args = split_cmd_args(cmdline)
  local arg_index = #args

  local entries = type(registry.list_entries) == "function" and registry.list_entries() or {}
  local names_seen = {}
  local names = {}
  local tokens = {}

  for _, entry in ipairs(entries) do
    if type(entry.name) == "string" and entry.name ~= "" then
      if not names_seen[entry.name] then
        names_seen[entry.name] = true
        table.insert(names, entry.name)
      end

      if type(entry.variant) == "string" and entry.variant ~= "" then
        table.insert(tokens, string.format("%s:%s", entry.name, entry.variant))
      end
    end
  end

  local matches = {}
  local seen = {}

  if arg_index <= 1 then
    for _, value in ipairs(names) do
      if prefix_match(value, arglead) and not seen[value] then
        seen[value] = true
        table.insert(matches, value)
      end
    end
    for _, value in ipairs(tokens) do
      if prefix_match(value, arglead) and not seen[value] then
        seen[value] = true
        table.insert(matches, value)
      end
    end
    table.sort(matches)
    return matches
  end

  local base_name = args[1]
  if type(base_name) ~= "string" or base_name == "" then
    return {}
  end

  if base_name:find(":", 1, true) then
    return {}
  end

  local resolved = type(registry.get_theme) == "function" and registry.get_theme(base_name) or nil
  if type(resolved) == "table" and type(resolved.name) == "string" then
    base_name = resolved.name
  end

  for _, entry in ipairs(entries) do
    if entry.name == base_name then
      local variant = entry.variant
      if type(variant) == "string" and variant ~= "" and prefix_match(variant, arglead) and not seen[variant] then
        seen[variant] = true
        table.insert(matches, variant)
      end
    end
  end

  table.sort(matches)
  return matches
end

---Setup plugin commands
local function setup_commands()
  vim.api.nvim_create_user_command("ThemeBrowser", function(opts)
    local ui = require("theme-browser.ui.gallery")
    ui.open(opts.fargs[1])
  end, {
    nargs = "?",
    complete = function(arglead)
      local registry = ensure_registry_for_completion()
      local themes = registry and registry.list_themes() or {}
      local matches = {}
      for _, theme in ipairs(themes) do
        if prefix_match(theme.name, arglead) then
          table.insert(matches, theme.name)
        end
      end
      return matches
    end,
  })

  vim.api.nvim_create_user_command("ThemeBrowserFocus", function()
    local ui = require("theme-browser.ui.gallery")
    if not ui.focus() then
      ui.open()
    end
  end, {})

  vim.api.nvim_create_user_command("ThemeBrowserTheme", function(opts)
    local theme_name, variant = parse_theme_args(opts.fargs)
    if not theme_name then
      log.warn("Usage: :ThemeBrowserTheme <theme-name[:variant]> [variant]")
      return
    end

    local theme_service = require("theme-browser.application.theme_service")
    theme_service.apply(theme_name, variant)
  end, {
    nargs = "*",
    complete = complete_theme_command,
  })

  vim.api.nvim_create_user_command("ThemeBrowserStatus", function(opts)
    local status = require("theme-browser.ui.status")
    status.show(opts.fargs[1])
  end, {
    nargs = "?",
  })

  vim.api.nvim_create_user_command("ThemeBrowserMark", function(opts)
    local theme_name, variant = parse_theme_args(opts.fargs)
    if not theme_name then
      log.warn("Usage: :ThemeBrowserMark <theme-name[:variant]> [variant]")
      return
    end

    local state = require("theme-browser.persistence.state")
    state.mark_theme(theme_name, variant)
    if variant and variant ~= "" then
      log.info("Theme '" .. theme_name .. ":" .. variant .. "' marked for install")
    else
      log.info("Theme '" .. theme_name .. "' marked for install")
    end
  end, {
    nargs = "*",
    complete = complete_theme_command,
  })

  vim.api.nvim_create_user_command("ThemeBrowserCacheClear", function()
    run_cache_cleanup(true, true)
  end, {})

  vim.api.nvim_create_user_command("ThemeBrowserClean", function()
    run_cache_cleanup(true, true)
  end, {})

  vim.api.nvim_create_user_command("ThemeBrowserCacheInfo", function()
    local cache = require("theme-browser.downloader.cache")
    local stats = cache.get_stats()
    log.info(string.format("Cache stats: %d hits, %d misses", stats.hits, stats.misses))
  end, {})

  vim.api.nvim_create_user_command("ThemeBrowserPreview", function(opts)
    local theme_name, variant = parse_theme_args(opts.fargs)
    if not theme_name then
      log.warn("Usage: :ThemeBrowserPreview <theme-name[:variant]> [variant]")
      return
    end

    local theme_service = require("theme-browser.application.theme_service")
    theme_service.preview(theme_name, variant)
  end, {
    nargs = "*",
    complete = complete_theme_command,
  })

  vim.api.nvim_create_user_command("ThemeBrowserInstall", function(opts)
    local theme_name, variant = parse_theme_args(opts.fargs)
    if not theme_name then
      log.warn("Usage: :ThemeBrowserInstall <theme-name[:variant]> [variant]")
      return
    end

    local theme_service = require("theme-browser.application.theme_service")
    theme_service.install(theme_name, variant, {
      wait_install = opts.bang == true,
    })
  end, {
    nargs = "*",
    bang = true,
    complete = complete_theme_command,
  })

  vim.api.nvim_create_user_command("ThemeBrowserUninstall", function(_)
    local lazy_spec = require("theme-browser.persistence.lazy_spec")
    lazy_spec.remove_spec()
    log.info("Theme removed from configuration")
  end, {})

  vim.api.nvim_create_user_command("ThemeBrowserReset", function()
    local cache = require("theme-browser.downloader.cache")
    local state = require("theme-browser.persistence.state")
    local lazy_spec = require("theme-browser.persistence.lazy_spec")
    local preview = require("theme-browser.preview.manager")

    cache.clear_all({ notify = false })
    lazy_spec.remove_spec({ notify = false })
    state.reset()
    preview.cleanup()

    log.info("Theme Browser reset complete (state, cache, and managed spec removed)")
  end, {})

  vim.api.nvim_create_user_command("ThemeBrowserHelp", function()
    local lines = {
      "  :ThemeBrowserClean                    - Clean cache now",
      "  :ThemeBrowserCacheClear               - Clear all cache",
      "  :ThemeBrowserCacheInfo                - Show cache statistics",
      "  :ThemeBrowserReset                    - Reset state, cache, and managed spec",
      "  :ThemeBrowserPreview <name> [variant] - Preview theme",
      "  :ThemeBrowserInstall[!] <name> [variant] - Install/apply now (! waits)",
      "  :ThemeBrowserMark <name> [variant]    - Mark theme for install",
      "  :ThemeBrowserUninstall                - Remove theme from LazyVim config",
      "  :ThemeBrowserStatus [name]            - Show theme status",
      "  :ThemeBrowserTheme <name> [variant]   - Apply and persist theme",
      "  :ThemeBrowserHelp                     - Show this help",
    }

    vim.api.nvim_echo({ { table.concat(lines, "\n"), "Normal" } }, false, {})
  end, {})
end

local function sync_state_from_current_colorscheme(state, registry)
  if state.get_current_theme() then
    return
  end

  local current_colorscheme = vim.g.colors_name
  if type(current_colorscheme) ~= "string" or current_colorscheme == "" then
    return
  end

  local entry = nil
  if type(registry.get_entry) == "function" then
    entry = registry.get_entry(current_colorscheme)
  end
  if not entry and type(registry.resolve) == "function" then
    entry = registry.resolve(current_colorscheme, nil)
  end

  if entry and type(entry.name) == "string" then
    state.set_current_theme(entry.name, entry.variant)
  end
end

local function schedule_weekly_cache_cleanup()
  vim.schedule(function()
    local ok, cache = pcall(require, "theme-browser.downloader.cache")
    if not ok or type(cache.maybe_cleanup) ~= "function" then
      return
    end
    cache.maybe_cleanup({ notify = false })
  end)
end

local function migrate_managed_lazy_spec()
  local ok_lazy_spec, lazy_spec = pcall(require, "theme-browser.persistence.lazy_spec")
  if not ok_lazy_spec or type(lazy_spec.migrate_to_cache_aware) ~= "function" then
    return
  end

  local ok_migration, result = pcall(lazy_spec.migrate_to_cache_aware, {
    notify = false,
  })
  if not ok_migration then
    log.warn(string.format("Managed spec migration failed: %s", result))
    return
  end

  if type(result) == "table" and result.reason == "write_failed" then
    local path = type(result.spec_file) == "string" and result.spec_file or "managed lazy spec"
    log.warn(string.format("Managed spec migration could not update: %s", path))
  end
end

---Setup theme-browser plugin
---@param user_config Config|nil
---@return ThemeBrowser
function M.setup(user_config)
  if M.initialized then
    return M
  end

  local validated_config = validate_config(user_config)
  local resolved_registry = registry_config.resolve(validated_config.registry_path)

  local user_registry = type(user_config) == "table" and user_config.registry_path or nil
  if type(user_registry) == "string" and user_registry ~= "" and resolved_registry.source ~= "user" then
    vim.notify(
      string.format("Configured registry_path not found: %s. Falling back to %s", user_registry, resolved_registry.path),
      vim.log.levels.WARN
    )
  end

  if resolved_registry.source == "missing" then
    vim.notify(
      string.format("Theme registry not found. Tried fallback paths; expected bundled path at %s", resolved_registry.path),
      vim.log.levels.WARN
    )
  end

  validated_config.registry_path = resolved_registry.path
  M.config = validated_config

  local state = require("theme-browser.persistence.state")
  state.initialize(M.config)

  local registry = require("theme-browser.adapters.registry")
  registry.initialize(M.config.registry_path)

  migrate_managed_lazy_spec()

  sync_state_from_current_colorscheme(state, registry)
  schedule_weekly_cache_cleanup()

  setup_commands()

  vim.api.nvim_create_autocmd("User", {
    pattern = "CheckHealth theme_browser",
    callback = function()
      local health = require("theme-browser.health")
      health.check()
    end,
  })

  if M.config.auto_load and state.get_current_theme() then
    local package_manager = require("theme-browser.package_manager.manager")
    package_manager.when_ready(function()
      startup_restore.restore_current_theme(M.config, state, registry)
    end)
  end

  M.initialized = true
  return M
end

---@return Config
function M.get_config()
  return M.config
end

---@return boolean
function M.is_initialized()
  return M.initialized
end

return M
