local M = {}

---Check health of plugin
function M.check()
  vim.health.start("Theme Browser")

  local ok, theme_browser = pcall(require, "theme-browser")

  if not ok or type(theme_browser.get_config) ~= "function" then
    vim.health.error("Plugin not initialized. Call require('theme-browser').setup()")
    return
  end

  local config = theme_browser.get_config()
  if type(config) ~= "table" or type(config.registry_path) ~= "string" or config.registry_path == "" then
    vim.health.error("Plugin not initialized. Call require('theme-browser').setup()")
    return
  end

  M.check_registry(config.registry_path)
  M.check_cache(config.cache_dir)
  M.check_dependencies()
  M.check_state()
end

---Check registry
---@param registry_path string
function M.check_registry(registry_path)
  local file = io.open(registry_path, "r")

  if not file then
    vim.health.warn(string.format("Registry not found at: %s", registry_path))
    return
  end

  local content = file:read("*a")
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)

  if not ok then
    vim.health.error("Invalid JSON in registry file")
    return
  end

  local theme_count = #decoded
  vim.health.ok(string.format("Registry loaded with %d themes", theme_count))
end

---Check cache directory
---@param cache_dir string
function M.check_cache(cache_dir)
  if vim.fn.isdirectory(cache_dir) == 1 then
    vim.health.ok(string.format("Cache directory exists: %s", cache_dir))
  else
    vim.health.warn(string.format("Cache directory not found: %s", cache_dir))
  end
end

---Check dependencies
function M.check_dependencies()

  if vim.fn.executable("git") == 1 then
    vim.health.ok("git executable found")
  else
    vim.health.error("git executable not found (required for downloading themes)")
  end

  if vim.fn.has("nvim-0.8") == 1 then
    vim.health.ok("Neovim >= 0.8")
  else
    vim.health.error("Neovim < 0.8 not supported")
  end

  local has_plenary, _ = pcall(require, "plenary")
  if has_plenary then
    vim.health.ok("plenary.nvim found")
  else
    vim.health.warn("plenary.nvim not found (recommended for async operations)")
  end
end

---Check state file
function M.check_state()
  local state_file = vim.fn.stdpath("data") .. "/theme-browser/state.json"

  if vim.fn.filereadable(state_file) == 1 then
    vim.health.ok(string.format("State file found: %s", state_file))
  else
    vim.health.warn(string.format("State file not found: %s", state_file))
  end

  local spec_file = vim.fn.stdpath("config") .. "/lua/plugins/theme-browser-selected.lua"
  local legacy_spec_file = vim.fn.stdpath("config") .. "/lua/plugins/selected-theme.lua"
  if vim.fn.filereadable(spec_file) == 1 then
    vim.health.ok(string.format("LazyVim spec found: %s", spec_file))
  elseif vim.fn.filereadable(legacy_spec_file) == 1 then
    vim.health.ok(string.format("LazyVim legacy spec found: %s", legacy_spec_file))
  else
    vim.health.warn(string.format("LazyVim spec not found: %s", spec_file))
  end
end

return M
