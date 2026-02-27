local log = require("theme-browser.util.notify")
local registry_config = require("theme-browser.config.registry")
local startup_restore = require("theme-browser.startup.restore")
local startup_config = require("theme-browser.startup.config")

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

local function complete_from_values(values, arglead)
  local matches = {}
  local seen = {}

  for _, value in ipairs(values) do
    if prefix_match(value, arglead) and not seen[value] then
      seen[value] = true
      table.insert(matches, value)
    end
  end

  table.sort(matches)
  return matches
end

local function complete_theme_targets(arglead)
  local registry = ensure_registry_for_completion()
  if not registry or type(registry.list_entries) ~= "function" then
    return {}
  end

  local entries = registry.list_entries() or {}
  local names = {}
  local names_seen = {}
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

  local values = {}
  for _, value in ipairs(names) do
    table.insert(values, value)
  end
  for _, value in ipairs(tokens) do
    table.insert(values, value)
  end

  return complete_from_values(values, arglead)
end

local function complete_theme_variants(arglead, base_name)
  if type(base_name) ~= "string" or base_name == "" or base_name:find(":", 1, true) then
    return {}
  end

  local registry = ensure_registry_for_completion()
  if not registry or type(registry.list_entries) ~= "function" or type(registry.get_theme) ~= "function" then
    return {}
  end

  local resolved = registry.get_theme(base_name)
  if type(resolved) == "table" and type(resolved.name) == "string" then
    base_name = resolved.name
  end

  local entries = registry.list_entries() or {}
  local variants = {}
  local seen = {}

  for _, entry in ipairs(entries) do
    if entry.name == base_name and type(entry.variant) == "string" and entry.variant ~= "" then
      if not seen[entry.variant] then
        seen[entry.variant] = true
        table.insert(variants, entry.variant)
      end
    end
  end

  return complete_from_values(variants, arglead)
end

local function complete_theme_browser_command(arglead, cmdline)
  local args = split_cmd_args(cmdline)
  local argc = #args
  local action = type(args[1]) == "string" and string.lower(args[1]) or ""

  if argc <= 1 then
    local values =
      { "pick", "focus", "use", "status", "pm", "browser", "registry", "validate", "reset", "help" }
    local matches = complete_from_values(values, arglead)
    for _, value in ipairs(complete_theme_targets(arglead)) do
      table.insert(matches, value)
    end
    return complete_from_values(matches, arglead)
  end

  if action == "pick" then
    if argc == 2 then
      return complete_theme_targets(arglead)
    end
    return {}
  end

  if action == "focus" then
    return {}
  end

  if action == "use" then
    if argc == 2 then
      return complete_theme_targets(arglead)
    end
    if argc == 3 then
      return complete_theme_variants(arglead, args[2])
    end
    return {}
  end

  if action == "status" then
    if argc == 2 then
      return complete_theme_targets(arglead)
    end
    return {}
  end

  if action == "pm" then
    if argc == 2 then
      return complete_from_values({ "enable", "disable", "toggle", "status" }, arglead)
    end
    return {}
  end

  if action == "browser" then
    if argc == 2 then
      return complete_from_values({ "enable", "disable", "toggle", "status" }, arglead)
    end
    return {}
  end

  if action == "registry" then
    if argc == 2 then
      return complete_from_values({ "sync", "clear" }, arglead)
    end
    return {}
  end

  return {}
end

local function with_package_manager_state(callback)
  local ok_state, state = pcall(require, "theme-browser.persistence.state")
  if
    not ok_state
    or type(state.get_package_manager) ~= "function"
    or type(state.set_package_manager) ~= "function"
  then
    log.warn("Theme Browser package manager state is unavailable")
    return
  end

  local pm = state.get_package_manager() or {}
  local mode = type(pm.mode) == "string" and pm.mode ~= "" and pm.mode or "manual"
  local provider = type(pm.provider) == "string" and pm.provider ~= "" and pm.provider or "auto"
  callback(state, pm.enabled == true, mode, provider)
end

local function with_browser_state(callback)
  local ok_state, state = pcall(require, "theme-browser.persistence.state")
  if
    not ok_state
    or type(state.get_browser_enabled) ~= "function"
    or type(state.set_browser_enabled) ~= "function"
    or type(state.get_current_theme) ~= "function"
  then
    log.warn("Theme Browser state is unavailable")
    return
  end

  callback(state, state.get_browser_enabled() == true)
end

local function set_package_manager_enabled(enabled)
  with_package_manager_state(function(state, _, mode, provider)
    state.set_package_manager(enabled == true, mode, provider)
    log.info(string.format("Theme Browser package manager %s", enabled and "enabled" or "disabled"))
  end)
end

local function run_package_manager_action(action)
  if action == "enable" then
    set_package_manager_enabled(true)
    return true
  end

  if action == "disable" then
    set_package_manager_enabled(false)
    return true
  end

  if action == "toggle" then
    with_package_manager_state(function(_, enabled)
      set_package_manager_enabled(not enabled)
    end)
    return true
  end

  if action == "status" then
    with_package_manager_state(function(_, enabled)
      log.info(string.format("Theme Browser package manager is %s", enabled and "enabled" or "disabled"))
    end)
    return true
  end

  return false
end

local function run_browser_action(action)
  if action == "status" then
    with_browser_state(function(_, enabled)
      log.info(string.format("Theme Browser startup restore is %s", enabled and "enabled" or "disabled"))
    end)
    return true
  end

  if action == "disable" then
    with_browser_state(function(state, enabled)
      if not enabled then
        log.info("Theme Browser is already disabled")
        return
      end

      state.set_browser_enabled(false)
      log.info("Theme Browser disabled (themes will not load on startup)")
    end)
    return true
  end

  if action == "enable" then
    with_browser_state(function(state, enabled)
      if enabled then
        log.info("Theme Browser is already enabled")
        return
      end

      state.set_browser_enabled(true)

      local last_theme = state.get_current_theme()
      if last_theme then
        local theme_service = require("theme-browser.application.theme_service")
        theme_service.use(last_theme.name, last_theme.variant, { notify = true })
      else
        log.info("Theme Browser enabled (no saved theme to restore)")
      end
    end)
    return true
  end

  if action == "toggle" then
    with_browser_state(function(state, enabled)
      if enabled then
        state.set_browser_enabled(false)
        log.info("Theme Browser disabled (themes will not load on startup)")
        return
      end

      state.set_browser_enabled(true)

      local last_theme = state.get_current_theme()
      if last_theme then
        local theme_service = require("theme-browser.application.theme_service")
        theme_service.use(last_theme.name, last_theme.variant, { notify = true })
      else
        log.info("Theme Browser enabled (no saved theme to restore)")
      end
    end)
    return true
  end

  return false
end

local function run_registry_action(action, opts)
  opts = opts or {}

  if action == "sync" then
    local registry_sync = require("theme-browser.registry.sync")
    registry_sync.sync({ force = opts.force == true }, function(success, message, count)
      vim.schedule(function()
        if success then
          if message == "updated" then
            log.info(string.format("Registry synced: %d themes", count or 0))
          else
            log.info("Registry is up to date")
          end

          local registry = require("theme-browser.adapters.registry")
          local new_path = registry_sync.get_synced_registry_path()
          if new_path then
            registry.initialize(new_path)
          end
        else
          log.warn(string.format("Registry sync failed: %s", message or "unknown error"))
        end
      end)
    end)
    return true
  end

  if action == "clear" then
    local registry_sync = require("theme-browser.registry.sync")
    registry_sync.clear_synced_registry()

    local registry = require("theme-browser.adapters.registry")
    local resolved = registry_config.resolve(M.config.registry_path)
    registry.initialize(resolved.path)

    log.info("Synced registry cleared, using bundled fallback")
    return true
  end

  return false
end

local function run_reset_action()
  local cache = require("theme-browser.downloader.cache")
  local state = require("theme-browser.persistence.state")
  local lazy_spec = require("theme-browser.persistence.lazy_spec")
  local preview = require("theme-browser.preview.manager")

  cache.clear_all({ notify = false })
  lazy_spec.remove_spec({ notify = false })
  state.reset()
  preview.cleanup()

  log.info("Theme Browser reset complete (state, cache, and managed spec removed)")
end

local function run_validate_action(output)
  local soak = require("theme-browser.validation.soak")
  local report = soak.run({ output_path = output })
  if report.ok then
    log.info(
      string.format(
        "Validation passed: %d/%d entries, notifications=%d, report=%s",
        report.ok_count,
        report.total_entries,
        report.notify_count,
        report.output_path
      )
    )
  else
    log.warn(
      string.format(
        "Validation failed: ok=%d fail=%d notifications=%d, report=%s",
        report.ok_count,
        report.fail_count,
        report.notify_count,
        report.output_path
      )
    )
  end
end

local function run_help_action()
  local lines = {
    "  :ThemeBrowser                          - Open theme picker",
    "  :ThemeBrowser pick [query]             - Open picker with optional initial filter",
    "  :ThemeBrowser focus                    - Focus existing picker window",
    "  :ThemeBrowser use <name[:variant]> [variant] - Install/load/apply and persist",
    "  :ThemeBrowser status [name]            - Show theme status",
    "  :ThemeBrowser pm <enable|disable|toggle|status> - Package manager controls",
    "  :ThemeBrowser browser <enable|disable|toggle|status> - Startup restore controls",
    "  :ThemeBrowser registry <sync|clear>    - Sync or clear registry cache",
    "  :ThemeBrowser! registry sync           - Force registry sync",
    "  :ThemeBrowser validate [output]        - Validate install/preview/use over registry",
    "  :ThemeBrowser reset                    - Reset state, cache, and managed spec",
    "  :ThemeBrowser help                     - Show this help",
  }

  vim.api.nvim_echo({ { table.concat(lines, "\n"), "Normal" } }, false, {})
end

local function setup_commands()
  vim.api.nvim_create_user_command("ThemeBrowser", function(opts)
    local action = type(opts.fargs[1]) == "string" and string.lower(opts.fargs[1]) or ""
    local picker = require("theme-browser.picker")

    if action == "" then
      if picker.focus() then
        return
      end
      picker.pick()
      return
    end

    if action == "pick" then
      local query = opts.fargs[2]
      if (query == nil or query == "") and picker.focus() then
        return
      end
      picker.pick({ initial_theme = query })
      return
    end

    if action == "focus" then
      if not picker.focus() then
        log.warn("Theme picker window is not open")
      end
      return
    end

    if action == "use" then
      local use_args = {}
      for i = 2, #opts.fargs do
        table.insert(use_args, opts.fargs[i])
      end

      local theme_name, variant = parse_theme_args(use_args)
      if not theme_name then
        log.warn("Usage: :ThemeBrowser use <theme-name[:variant]> [variant]")
        return
      end

      local theme_service = require("theme-browser.application.theme_service")
      theme_service.use(theme_name, variant, {
        wait_install = true,
      })
      return
    end

    if action == "status" then
      local status = require("theme-browser.ui.status")
      status.show(opts.fargs[2])
      return
    end

    if action == "pm" then
      local pm_action = type(opts.fargs[2]) == "string" and string.lower(opts.fargs[2]) or ""
      if not run_package_manager_action(pm_action) then
        log.warn("Usage: :ThemeBrowser pm <enable|disable|toggle|status>")
      end
      return
    end

    if action == "browser" then
      local browser_action = type(opts.fargs[2]) == "string" and string.lower(opts.fargs[2]) or ""
      if not run_browser_action(browser_action) then
        log.warn("Usage: :ThemeBrowser browser <enable|disable|toggle|status>")
      end
      return
    end

    if action == "registry" then
      local registry_action = type(opts.fargs[2]) == "string" and string.lower(opts.fargs[2]) or ""
      if registry_action == "" and opts.bang then
        registry_action = "sync"
      end

      if not run_registry_action(registry_action, { force = opts.bang }) then
        log.warn("Usage: :ThemeBrowser registry <sync|clear>")
      end
      return
    end

    if action == "validate" then
      run_validate_action(opts.fargs[2])
      return
    end

    if action == "reset" then
      run_reset_action()
      return
    end

    if action == "help" then
      run_help_action()
      return
    end

    picker.pick({ initial_theme = opts.fargs[1] })
  end, {
    nargs = "*",
    bang = true,
    complete = complete_theme_browser_command,
  })
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

local function should_run_startup_restore(state)
  if not M.config.auto_load then
    return false
  end

  if not state.get_browser_enabled() then
    return false
  end

  if not state.get_current_theme() then
    return false
  end

  local ok_lazy_spec, lazy_spec = pcall(require, "theme-browser.persistence.lazy_spec")
  local startup = startup_config.resolve(M.config)
  if
    startup.enabled
    and startup.write_spec
    and ok_lazy_spec
    and type(lazy_spec.has_managed_spec) == "function"
    and lazy_spec.has_managed_spec()
  then
    return false
  end

  return true
end

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
      string.format(
        "Configured registry_path not found: %s. Falling back to %s",
        user_registry,
        resolved_registry.path
      ),
      vim.log.levels.WARN
    )
  end

  if resolved_registry.source == "missing" then
    vim.notify(
      string.format(
        "Theme registry not found. Tried fallback paths; expected bundled path at %s",
        resolved_registry.path
      ),
      vim.log.levels.WARN
    )
  end

  validated_config.registry_path = resolved_registry.path
  M.config = validated_config

  local state = require("theme-browser.persistence.state")
  state.initialize(M.config)

  local registry = require("theme-browser.adapters.registry")
  registry.initialize(M.config.registry_path)

  local registry_sync = require("theme-browser.registry.sync")
  registry_sync.sync({ notify = false }, function(success, message, count)
    if success then
      local synced_path = registry_sync.get_synced_registry_path()
      if synced_path then
        registry.initialize(synced_path)
      end
    end
  end)

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

  if should_run_startup_restore(state) then
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
