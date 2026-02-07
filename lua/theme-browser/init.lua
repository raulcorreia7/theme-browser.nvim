local log = require("theme-browser.util.log")
local startup_restore = require("theme-browser.startup.restore")

---@class ThemeBrowser
---@field config Config
---@field private initialized boolean

local M = {
  initialized = false,
  config = {},
}

---Load default configuration
local function load_defaults()
  local defaults = require("theme-browser.config.defaults")
  return vim.deepcopy(defaults)
end

---Validate and merge user configuration
---@param user_config Config|nil
---@return Config
local function validate_config(user_config)
  local options = require("theme-browser.config.options")
  return options.validate(user_config)
end

---Merge user config with defaults
---@param defaults Config
---@param user_config Config|nil
---@return Config
local function merge_config(defaults, user_config)
  if not user_config then
    return defaults
  end

  local result = vim.deepcopy(defaults)

  for key, value in pairs(user_config) do
    if type(value) == "table" and type(result[key]) == "table" then
      result[key] = vim.tbl_extend("force", result[key], value)
    else
      result[key] = value
    end
  end

  return result
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

---Setup plugin commands
local function setup_commands()
  vim.api.nvim_create_user_command("ThemeBrowser", function(opts)
    local ui = require("theme-browser.ui.gallery")
    ui.open(opts.fargs[1])
  end, {
    nargs = "?",
    complete = function(arglead)
      local registry = require("theme-browser.adapters.registry")
      local themes = registry.list_themes()
      local matches = {}
      for _, theme in ipairs(themes) do
        if theme.name:find(arglead, 1, true) then
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
    if not opts.fargs[1] then
      log.warn("Usage: :ThemeBrowserTheme <theme-name> [variant]")
      return
    end

    local theme_service = require("theme-browser.application.theme_service")
    theme_service.apply(opts.fargs[1], opts.fargs[2])
  end, {
    nargs = "*",
  })

  vim.api.nvim_create_user_command("ThemeBrowserStatus", function(opts)
    local status = require("theme-browser.ui.status")
    status.show(opts.fargs[1])
  end, {
    nargs = "?",
  })

  vim.api.nvim_create_user_command("ThemeBrowserMark", function(opts)
    if not opts.fargs[1] then
      log.warn("Usage: :ThemeBrowserMark <theme-name> [variant]")
      return
    end

    local state = require("theme-browser.persistence.state")
    state.mark_theme(opts.fargs[1], opts.fargs[2])
    if opts.fargs[2] and opts.fargs[2] ~= "" then
      log.info("Theme '" .. opts.fargs[1] .. ":" .. opts.fargs[2] .. "' marked for install")
    else
      log.info("Theme '" .. opts.fargs[1] .. "' marked for install")
    end
  end, {
    nargs = "*",
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
    if not opts.fargs[1] then
      log.warn("Usage: :ThemeBrowserPreview <theme-name> [variant]")
      return
    end

    local theme_service = require("theme-browser.application.theme_service")
    theme_service.preview(opts.fargs[1], opts.fargs[2])
  end, {
    nargs = "*",
  })

  vim.api.nvim_create_user_command("ThemeBrowserInstall", function(opts)
    if not opts.fargs[1] then
      log.warn("Usage: :ThemeBrowserInstall <theme-name> [variant]")
      return
    end

    local theme_service = require("theme-browser.application.theme_service")
    theme_service.install(opts.fargs[1], opts.fargs[2], {
      wait_install = opts.bang == true,
    })
  end, {
    nargs = "*",
    bang = true,
  })

  vim.api.nvim_create_user_command("ThemeBrowserUninstall", function(opts)
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

---Setup theme-browser plugin
---@param user_config Config|nil
---@return ThemeBrowser
function M.setup(user_config)
  if M.initialized then
    return M
  end

  -- Load and validate configuration
  local defaults = load_defaults()
  local validated_config = validate_config(user_config)
  M.config = merge_config(defaults, validated_config)

  -- Initialize components
  local state = require("theme-browser.persistence.state")
  state.initialize(M.config)

  local registry = require("theme-browser.adapters.registry")
  registry.initialize(M.config.registry_path)

  sync_state_from_current_colorscheme(state, registry)
  schedule_weekly_cache_cleanup()

  -- Setup commands
  setup_commands()

  -- Setup health checks
  vim.api.nvim_create_autocmd("User", {
    pattern = "CheckHealth theme_browser",
    callback = function()
      local health = require("theme-browser.health")
      health.check()
    end,
  })

  -- Auto-load theme if configured
  if M.config.auto_load and state.get_current_theme() then
    local package_manager = require("theme-browser.package_manager.manager")
    package_manager.when_ready(function()
      startup_restore.restore_current_theme(M.config, state, registry)
    end)
  end

  M.initialized = true

  return M
end

---Get current configuration
---@return Config
function M.get_config()
  return M.config
end

---Check if plugin is initialized
---@return boolean
function M.is_initialized()
  return M.initialized
end

---Plugin metadata for Neovim
return M
