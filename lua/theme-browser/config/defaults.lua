---@class Config
---@field registry_path string Path to themes.json
---@field cache_dir string Directory for theme cache
---@field default_theme string|nil Default theme on startup
---@field auto_load boolean Auto-load theme on startup
---@field startup table Startup workflow configuration
---@field cache table Cache maintenance configuration
---@field show_preview boolean Show preview buffer
---@field keymaps table Custom keymaps
---@field status_display table Status line configuration
---@field ui table UI customization
---@field package_manager table Package manager configuration

---@type Config
local function get_plugin_root()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  local absolute = vim.fn.fnamemodify(source, ":p")
  return vim.fn.fnamemodify(absolute, ":h:h:h:h")
end

local function get_default_registry_path()
  return get_plugin_root() .. "/theme-browser-registry/curated/dotfyle-top50.json"
end

local M = {
  -- Registry configuration
  registry_path = get_default_registry_path(),

  -- Cache configuration
  cache_dir = vim.fn.stdpath("cache") .. "/theme-browser",

  -- Default theme (nil = use system default)
  default_theme = nil,

  -- Auto-load persisted theme on startup
  auto_load = true,

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

  -- Show preview buffer when gallery opens
  show_preview = false,

  -- Notification verbosity: error|warn|info|debug
  log_level = "info",

  -- Package manager integration
  package_manager = {
    enabled = false,
    mode = "plugin_only",
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
    mark = { "m" },
    navigate_up = { "k" },
    navigate_down = { "j" },
    goto_top = { "gg" },
    goto_bottom = { "G" },
  },
}

return M
