---@class Config
---@field registry_path string Path to themes.json
---@field registry table Registry sync configuration
---@field cache_dir string Directory for theme cache
---@field auto_load boolean Auto-load theme on startup
---@field startup table Startup workflow configuration
---@field cache table Cache maintenance configuration
---@field keymaps table Custom keymaps
---@field status_display table Status line configuration
---@field ui table UI customization
---@field package_manager table Package manager configuration

---@type Config
local registry_config = require("theme-browser.config.registry")

local function get_default_registry_path()
  return registry_config.resolve(nil).path
end

local M = {
  -- Registry configuration
  registry_path = get_default_registry_path(),
  registry = {
    channel = "stable",
  },

  -- Cache configuration
  cache_dir = vim.fn.stdpath("cache") .. "/theme-browser",

  -- Auto-load persisted theme on startup
  auto_load = false,

  -- Startup workflow configuration
  startup = {
    enabled = true,
    write_spec = true,
    skip_if_already_active = true,
  },

  -- Cache maintenance configuration
  cache = {
    auto_cleanup = true,
    cleanup_interval_days = 7,
  },

  -- Notification verbosity: error|warn|info|debug
  log_level = "info",

  -- Package manager integration
  package_manager = {
    enabled = true,
    mode = "manual",
    provider = "auto",
  },

  -- UI configuration
  ui = {
    window_width = 0.6,
    window_height = 0.5,
    border = "rounded",
    show_hints = true,
    show_breadcrumbs = true,
    preview_on_move = true,
  },

  -- Status display configuration
  status_display = {
    show_adapter = true,
    show_repo = true,
    show_cache_stats = true,
  },

  -- Custom keymaps
  keymaps = {
    close = { "q", "<Esc>" },
    select = { "<CR>" },
    preview = { "p" },
    install = { "i" },
    set_main = { "m" },
    navigate_up = { "k", "<Up>", "<C-p>" },
    navigate_down = { "j", "<Down>", "<C-n>" },
    goto_top = { "gg" },
    goto_bottom = { "G" },
    scroll_down = { "<C-d>", "<PageDown>" },
    scroll_up = { "<C-u>", "<PageUp>" },
    search = { "/" },
    clear_search = { "c" },
    copy_repo = { "Y" },
    open_repo = { "O" },
  },
}

return M
