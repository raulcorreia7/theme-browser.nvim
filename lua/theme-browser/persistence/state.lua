local M = {}

local icons = require("theme-browser.util.icons")
local has_nerd_font = icons.has_nerd_font

local has_plenary_path, _ = pcall(require, "plenary.path")

local default_state = {
  current_theme = nil,
  startup_theme = nil,
  marked_theme = nil,
  theme_history = {},
  cache_stats = {
    hits = 0,
    misses = 0,
  },
  package_manager = {
    enabled = false,
    mode = "installed_only",
    provider = "auto",
  },
  pre_browser_theme = nil,
  browser_enabled = true,
}

---@class State
---@field current_theme table|nil {name, variant}
---@field startup_theme table|nil {name, variant, colorscheme, repo}
---@field marked_theme table|nil {name, variant}
---@field theme_history string[]
---@field cache_stats table {hits, misses}
---@field package_manager table {enabled, mode, provider}
---@field pre_browser_theme table|nil {name, variant} - theme before ThemeBrowser took over
---@field browser_enabled boolean - whether ThemeBrowser management is active

local state = vim.deepcopy(default_state)

local state_file = vim.fn.stdpath("data") .. "/theme-browser/state.json"
local state_dir = has_plenary_path and require("plenary.path"):new(state_file):parent().filename
  or vim.fn.fnamemodify(state_file, ":h")

local save_pending = false

local state_order = { "active", "installed", "cached", "marked" }

local function state_short_label(name)
  if name == "active" then
    return "Current"
  elseif name == "installed" then
    return "Installed"
  elseif name == "cached" then
    return "Downloaded"
  elseif name == "marked" then
    return "Marked"
  end
  return name
end

local function normalize_variant(variant)
  if variant == "" then
    return nil
  end
  return variant
end

local function normalize_optional_string(value)
  if type(value) ~= "string" then
    return nil
  end
  if value == "" then
    return nil
  end
  return value
end

local function sanitize_startup_theme(theme)
  if type(theme) ~= "table" then
    return nil
  end

  local variant
  if type(theme.variant) == "string" then
    variant = normalize_variant(theme.variant)
  end

  local normalized = {
    name = normalize_optional_string(theme.name),
    variant = variant,
    colorscheme = normalize_optional_string(theme.colorscheme),
    repo = normalize_optional_string(theme.repo),
  }

  if normalized.name == nil and normalized.colorscheme == nil and normalized.repo == nil then
    return nil
  end

  return normalized
end

local function sanitize_marked_theme(marked_theme)
  if type(marked_theme) == "string" then
    local name = normalize_optional_string(marked_theme)
    if name == nil then
      return nil
    end

    return {
      name = name,
      variant = nil,
    }
  end

  if type(marked_theme) ~= "table" then
    return nil
  end

  local name = normalize_optional_string(marked_theme.name)
  if name == nil then
    return nil
  end

  return {
    name = name,
    variant = normalize_variant(marked_theme.variant),
  }
end

local function entry_matches_marked_theme(entry)
  if type(entry) ~= "table" or type(entry.name) ~= "string" then
    return false
  end

  local marked_theme = state.marked_theme
  if type(marked_theme) ~= "table" or type(marked_theme.name) ~= "string" then
    return false
  end

  if marked_theme.name ~= entry.name then
    return false
  end

  if marked_theme.variant ~= nil then
    return normalize_variant(entry.variant) == marked_theme.variant
  end

  return true
end

local function entry_matches_current_theme(entry)
  if type(entry) ~= "table" then
    return false
  end

  local current = state.current_theme
  if type(current) ~= "table" or type(current.name) ~= "string" then
    return false
  end

  return current.name == entry.name and normalize_variant(current.variant) == normalize_variant(entry.variant)
end

local function get_cache_dir()
  local ok, theme_browser = pcall(require, "theme-browser")
  if ok and type(theme_browser.get_config) == "function" then
    local config = theme_browser.get_config()
    if type(config) == "table" and type(config.cache_dir) == "string" and config.cache_dir ~= "" then
      return config.cache_dir
    end
  end

  return vim.fn.stdpath("cache") .. "/theme-browser"
end

local function is_entry_installed(entry, snapshot)
  if type(entry) ~= "table" or type(entry.repo) ~= "string" or entry.repo == "" then
    return false
  end

  if snapshot and type(snapshot.installed_by_repo) == "table" then
    local cached = snapshot.installed_by_repo[entry.repo]
    if type(cached) == "boolean" then
      return cached
    end
  end

  local spec_files = {
    vim.fn.stdpath("config") .. "/lua/plugins/theme-browser-selected.lua",
    vim.fn.stdpath("config") .. "/lua/plugins/selected-theme.lua",
  }

  for _, spec_file in ipairs(spec_files) do
    if vim.fn.filereadable(spec_file) == 1 then
      local ok, lines = pcall(vim.fn.readfile, spec_file)
      if ok and type(lines) == "table" then
        local content = table.concat(lines, "\n")
        if content:find(entry.repo, 1, true) ~= nil then
          if snapshot and type(snapshot.installed_by_repo) == "table" then
            snapshot.installed_by_repo[entry.repo] = true
          end
          return true
        end
      end
    end
  end

  local _, repo_name = entry.repo:match("([^/]+)/(.+)")
  if type(repo_name) == "string" and repo_name ~= "" then
    local lazy_dir = vim.fn.stdpath("data") .. "/lazy/" .. repo_name
    if vim.fn.isdirectory(lazy_dir) == 1 then
      if snapshot and type(snapshot.installed_by_repo) == "table" then
        snapshot.installed_by_repo[entry.repo] = true
      end
      return true
    end
  end

  local ok_cfg, lazy_cfg = pcall(require, "lazy.core.config")
  if ok_cfg and type(lazy_cfg.plugins) == "table" then
    for plugin_name, plugin in pairs(lazy_cfg.plugins) do
      if plugin_name == entry.repo or plugin_name == entry.name then
        if snapshot and type(snapshot.installed_by_repo) == "table" then
          snapshot.installed_by_repo[entry.repo] = true
        end
        return true
      end
      if type(plugin) == "table" then
        if plugin.name == entry.name then
          if snapshot and type(snapshot.installed_by_repo) == "table" then
            snapshot.installed_by_repo[entry.repo] = true
          end
          return true
        end
        if plugin.url and type(plugin.url) == "string" and plugin.url:find(entry.repo, 1, true) then
          if snapshot and type(snapshot.installed_by_repo) == "table" then
            snapshot.installed_by_repo[entry.repo] = true
          end
          return true
        end
      end
    end
  end

  if snapshot and type(snapshot.installed_by_repo) == "table" then
    snapshot.installed_by_repo[entry.repo] = false
  end
  return false
end

local function is_entry_cached(entry, snapshot)
  if type(entry) ~= "table" or type(entry.repo) ~= "string" or entry.repo == "" then
    return false
  end

  if snapshot and type(snapshot.cached_by_repo) == "table" then
    local cached = snapshot.cached_by_repo[entry.repo]
    if type(cached) == "boolean" then
      return cached
    end
  end

  local ok, github = pcall(require, "theme-browser.downloader.github")
  if not ok or type(github.is_cached) ~= "function" then
    return false
  end

  local result = github.is_cached(entry.repo, get_cache_dir())
  if snapshot and type(snapshot.cached_by_repo) == "table" then
    snapshot.cached_by_repo[entry.repo] = result
  end
  return result
end

---@return table
function M.build_state_snapshot()
  return {
    installed_by_repo = {},
    cached_by_repo = {},
  }
end

---Ensure state directory exists
local function ensure_state_dir()
  if vim.fn.isdirectory(state_dir) == 0 then
    vim.fn.mkdir(state_dir, "p")
  end
end

local function write_state_sync()
  ensure_state_dir()
  local file = io.open(state_file, "w")
  if not file then
    vim.notify("Failed to save state", vim.log.levels.ERROR)
    return false
  end

  local content = vim.json.encode(state)
  file:write(content)
  file:close()
  return true
end

---Load state from disk
function M.load()
  state = vim.deepcopy(default_state)

  local file = io.open(state_file, "r")
  if not file then
    return
  end

  local content = file:read("*a")
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return
  end

  if type(decoded.current_theme) == "table" and type(decoded.current_theme.name) == "string" then
    state.current_theme = {
      name = decoded.current_theme.name,
      variant = normalize_variant(decoded.current_theme.variant),
    }
  end

  if type(decoded.startup_theme) == "table" then
    state.startup_theme = sanitize_startup_theme(decoded.startup_theme)
  end

  state.marked_theme = sanitize_marked_theme(decoded.marked_theme)

  if type(decoded.theme_history) == "table" then
    state.theme_history = {}
    for _, item in ipairs(decoded.theme_history) do
      if type(item) == "string" then
        table.insert(state.theme_history, item)
      end
    end
  end

  if type(decoded.cache_stats) == "table" then
    if type(decoded.cache_stats.hits) == "number" and decoded.cache_stats.hits >= 0 then
      state.cache_stats.hits = decoded.cache_stats.hits
    end
    if type(decoded.cache_stats.misses) == "number" and decoded.cache_stats.misses >= 0 then
      state.cache_stats.misses = decoded.cache_stats.misses
    end
  end

  if type(decoded.package_manager) == "table" then
    if type(decoded.package_manager.enabled) == "boolean" then
      state.package_manager.enabled = decoded.package_manager.enabled
    end
    if type(decoded.package_manager.mode) == "string" and decoded.package_manager.mode ~= "" then
      state.package_manager.mode = decoded.package_manager.mode
    end
    if type(decoded.package_manager.provider) == "string" and decoded.package_manager.provider ~= "" then
      state.package_manager.provider = decoded.package_manager.provider
    end
  end

  if type(decoded.pre_browser_theme) == "table" and type(decoded.pre_browser_theme.name) == "string" then
    state.pre_browser_theme = {
      name = decoded.pre_browser_theme.name,
      variant = normalize_variant(decoded.pre_browser_theme.variant),
    }
  end

  if type(decoded.browser_enabled) == "boolean" then
    state.browser_enabled = decoded.browser_enabled
  end
end

---Save state to disk (debounced)
function M.save()
  if save_pending then
    return
  end

  save_pending = true

  vim.schedule(function()
    vim.defer_fn(function()
      ensure_state_dir()
      write_state_sync()

      save_pending = false
    end, 100)
  end)
end

---Initialize state with config
---@param config Config
function M.initialize(config)
  M.load()

  if config.package_manager then
    state.package_manager = vim.tbl_extend("force", state.package_manager, config.package_manager)
  end

  M.save()
end

---Get current theme
---@return table|nil {name, variant}
function M.get_current_theme()
  return state.current_theme
end

---Get startup theme
---@return table|nil {name, variant, colorscheme, repo}
function M.get_startup_theme()
  return state.startup_theme
end

---Set startup theme
---@param theme table
function M.set_startup_theme(theme)
  local normalized = sanitize_startup_theme(theme)
  if not normalized then
    return
  end

  state.startup_theme = normalized
  M.save()
end

---Clear startup theme
function M.clear_startup_theme()
  state.startup_theme = nil
  M.save()
end

---Set current theme
---@param name string Theme name
---@param variant string|nil Theme variant
function M.set_current_theme(name, variant)
  -- Save current theme as pre_browser_theme if this is the first ThemeBrowser theme
  if state.browser_enabled and not state.pre_browser_theme then
    local current = state.current_theme
    if current and type(current.name) == "string" then
      state.pre_browser_theme = {
        name = current.name,
        variant = normalize_variant(current.variant),
      }
    end
  end

  if state.current_theme and state.current_theme.name ~= name then
    table.insert(state.theme_history, 1, state.current_theme.name)
    if #state.theme_history > 10 then
      table.remove(state.theme_history)
    end
  end

  state.current_theme = { name = name, variant = normalize_variant(variant) }
  M.save()
end

---Get marked theme for install
---@return table|nil {name, variant}
function M.get_marked_theme()
  return state.marked_theme
end

---Mark theme for install
---@param name string Theme name
---@param variant string|nil Theme variant
function M.mark_theme(name, variant)
  local normalized_name = normalize_optional_string(name)
  if normalized_name == nil then
    return
  end

  state.marked_theme = {
    name = normalized_name,
    variant = normalize_variant(variant),
  }
  M.save()
end

---Unmark theme
function M.unmark_theme()
  state.marked_theme = nil
  M.save()
end

---Get theme history
---@return string[]
function M.get_history()
  return state.theme_history
end

---Get cache statistics
---@return table {hits, misses}
function M.get_cache_stats()
  return state.cache_stats
end

---Increment cache hit
function M.increment_cache_hit()
  state.cache_stats.hits = state.cache_stats.hits + 1
  M.save()
end

---Increment cache miss
function M.increment_cache_miss()
  state.cache_stats.misses = state.cache_stats.misses + 1
  M.save()
end

---Get package manager configuration
---@return table {enabled, mode, provider}
function M.get_package_manager()
  return state.package_manager
end

---Set package manager configuration
---@param enabled boolean
---@param mode string "auto" | "manual" | "installed_only"
---@param provider string|nil "auto" | "lazy" | "noop"
function M.set_package_manager(enabled, mode, provider)
  state.package_manager.enabled = enabled
  if mode then
    state.package_manager.mode = mode
  end
  if provider then
    state.package_manager.provider = provider
  end
  M.save()
end

---Get pre-browser theme (theme before ThemeBrowser was enabled)
---@return table|nil {name, variant}
function M.get_pre_browser_theme()
  return state.pre_browser_theme
end

---Set pre-browser theme
---@param theme table|nil {name, variant}
function M.set_pre_browser_theme(theme)
  if theme == nil then
    state.pre_browser_theme = nil
  elseif type(theme) == "table" and type(theme.name) == "string" then
    state.pre_browser_theme = {
      name = theme.name,
      variant = normalize_variant(theme.variant),
    }
  else
    state.pre_browser_theme = nil
  end
  M.save()
end

---Get browser enabled state
---@return boolean
function M.get_browser_enabled()
  return state.browser_enabled ~= false
end

---Set browser enabled state
---@param enabled boolean
function M.set_browser_enabled(enabled)
  state.browser_enabled = enabled == true
  M.save()
end

---Reset state to defaults and persist
function M.reset()
  state = vim.deepcopy(default_state)
  write_state_sync()
  save_pending = false
end

---@param entry table
---@param opts table|nil {snapshot:table|nil}
---@return table {active:boolean, selected:boolean, installed:boolean, cached:boolean, marked:boolean}
function M.get_entry_state(entry, opts)
  opts = opts or {}
  local snapshot = opts.snapshot

  local selected = entry_matches_current_theme(entry)
  return {
    active = selected,
    selected = selected,
    installed = is_entry_installed(entry, snapshot),
    cached = is_entry_cached(entry, snapshot),
    marked = entry_matches_marked_theme(entry),
  }
end

---@param entry table
---@param opts table|nil {all:boolean|nil, pretty:boolean|nil}
---@return string
function M.format_entry_states(entry, opts)
  opts = opts or {}

  local entry_state = M.get_entry_state(entry, opts)
  local labels = {}
  local pretty = opts.pretty == true
  local include_all = opts.all == true
  local nerd = has_nerd_font()
  local on_icon = nerd and "" or "+"
  local off_icon = nerd and "" or "-"

  for _, key in ipairs(state_order) do
    local enabled = entry_state[key] == true
    if include_all or enabled then
      if pretty then
        table.insert(labels, string.format("%s %s", enabled and on_icon or off_icon, state_short_label(key)))
      else
        if enabled then
          table.insert(labels, key)
        end
      end
    end
  end

  if #labels == 0 then
    return pretty and "Available" or "available"
  end

  if pretty then
    return table.concat(labels, " | ")
  end

  return table.concat(labels, ",")
end

---Cancel pending saves
local function cancel_pending_saves()
  save_pending = false
end

---Cleanup state on module unload
local function cleanup()
  if save_pending then
    write_state_sync()
  end
  cancel_pending_saves()
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = cleanup,
})

return M
