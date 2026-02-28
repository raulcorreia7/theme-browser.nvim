local M = {}
local log = require("theme-browser.util.notify")

local function get_spec_file()
  return vim.fn.stdpath("config") .. "/lua/plugins/theme-browser-selected.lua"
end

local function get_legacy_spec_file()
  return vim.fn.stdpath("config") .. "/lua/plugins/selected-theme.lua"
end

local function resolve_existing_spec_file()
  local preferred = get_spec_file()
  if vim.fn.filereadable(preferred) == 1 then
    return preferred
  end

  local legacy = get_legacy_spec_file()
  if vim.fn.filereadable(legacy) == 1 then
    return legacy
  end

  return preferred
end

local function read_spec_content(path)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  local lines = vim.fn.readfile(path)
  return table.concat(lines, "\n")
end

local function extract_repo(content)
  if type(content) ~= "string" or content == "" then
    return nil
  end

  return content:match('repo%s*=%s*"([^"]+)"')
    or content:match("repo%s*=%s*'([^']+)'")
    or content:match('local%s+theme_repo%s*=%s*"([^"]+)"')
    or content:match("local%s+theme_repo%s*=%s*'([^']+)'")
    or content:match('"([%w%._%-]+/[%w%._%-]+)"')
end

local function is_cache_aware_content(content)
  if type(content) ~= "string" then
    return false
  end

  return content:find("local function resolve_theme_source%(%)") ~= nil
    and content:find("dir = cache_path", 1, true) ~= nil
end

local function resolve_theme_from_repo(repo)
  if type(repo) ~= "string" or repo == "" then
    return nil
  end

  local ok_registry, registry = pcall(require, "theme-browser.adapters.registry")
  if not ok_registry or type(registry.list_themes) ~= "function" then
    return nil
  end

  local themes = registry.list_themes()
  for _, theme in ipairs(themes) do
    if type(theme) == "table" and theme.repo == repo then
      return theme
    end
  end

  return nil
end

local function ensure_parent_dir(path)
  local parent = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(parent) == 0 then
    vim.fn.mkdir(parent, "p")
  end
end

local function plugin_name_from_repo(repo, fallback)
  local repo_name = nil
  if type(repo) == "string" then
    local _, extracted = repo:match("([^/]+)/(.+)")
    repo_name = extracted
  end
  if type(repo_name) == "string" and repo_name ~= "" then
    return repo_name
  end
  return fallback
end

local function normalize_local_repo_sources(value)
  if type(value) == "string" then
    local trimmed = vim.trim(value)
    return trimmed ~= "" and { trimmed } or {}
  end

  if type(value) ~= "table" then
    return {}
  end

  local normalized = {}
  local seen = {}
  for _, item in ipairs(value) do
    if type(item) == "string" then
      local trimmed = vim.trim(item)
      if trimmed ~= "" and not seen[trimmed] then
        table.insert(normalized, trimmed)
        seen[trimmed] = true
      end
    end
  end

  return normalized
end

local function configured_local_repo_sources()
  local ok_theme_browser, theme_browser = pcall(require, "theme-browser")
  if not ok_theme_browser or type(theme_browser.get_config) ~= "function" then
    return {}
  end

  local config = theme_browser.get_config()
  if type(config) ~= "table" then
    return {}
  end

  local sources = normalize_local_repo_sources(config.local_repo_sources)
  if #sources > 0 then
    return sources
  end

  -- Backward compatibility for older configs using a singular key.
  return normalize_local_repo_sources(config.local_repo_source)
end

local function build_spec_content(entry, colorscheme, local_repo_sources)
  local theme_repo = entry.repo
  local plugin_name = plugin_name_from_repo(theme_repo, entry.name or "theme-browser-theme")
  local local_sources_literal = vim.inspect(local_repo_sources or {})
  return string.format(
    [[
local theme_repo = %q
local theme_plugin_name = %q
local local_repo_sources = %s

local function path_matches_repo(path, repo)
  if type(path) ~= "string" or path == "" or type(repo) ~= "string" or repo == "" then
    return false
  end

  local config_path = path .. "/.git/config"
  if vim.fn.filereadable(config_path) ~= 1 then
    return false
  end

  local ok, lines = pcall(vim.fn.readfile, config_path)
  if not ok or type(lines) ~= "table" then
    return false
  end

  local content = table.concat(lines, "\n"):lower()
  return content:find(repo:lower(), 1, true) ~= nil
end

local function append_unique_path(paths, candidate)
  if type(candidate) ~= "string" then
    return
  end

  local trimmed = vim.trim(candidate)
  if trimmed == "" then
    return
  end

  local normalized = vim.fn.fnamemodify(trimmed, ":p"):gsub("/$", "")
  if normalized == "" then
    return
  end

  for _, existing in ipairs(paths) do
    if existing == normalized then
      return
    end
  end

  table.insert(paths, normalized)
end

local function split_path_list(value)
  local parts = {}
  if type(value) ~= "string" or value == "" then
    return parts
  end

  for raw in value:gmatch("[^,;:]+") do
    local part = vim.trim(raw)
    if part ~= "" then
      table.insert(parts, part)
    end
  end
  return parts
end

local function collect_local_sources()
  local sources = {}

  local home = (vim.loop and vim.loop.os_homedir and vim.loop.os_homedir()) or vim.env.HOME
  if type(home) == "string" and home ~= "" then
    append_unique_path(sources, home .. "/projects")
  end

  for _, source in ipairs(local_repo_sources) do
    append_unique_path(sources, source)
  end

  local g_sources = vim.g.theme_browser_local_repo_sources
  if type(g_sources) == "string" then
    for _, source in ipairs(split_path_list(g_sources)) do
      append_unique_path(sources, source)
    end
  elseif type(g_sources) == "table" then
    for _, source in ipairs(g_sources) do
      append_unique_path(sources, source)
    end
  end

  for _, source in ipairs(split_path_list(vim.env.THEME_BROWSER_LOCAL_REPOS)) do
    append_unique_path(sources, source)
  end
  for _, source in ipairs(split_path_list(vim.env.THEME_BROWSER_LOCAL_THEME_SOURCES)) do
    append_unique_path(sources, source)
  end

  return sources
end

local function resolve_local_repo_path(repo)
  local _, repo_name = repo:match("([^/]+)/(.+)")
  if type(repo_name) ~= "string" or repo_name == "" then
    return nil
  end

  for _, source in ipairs(collect_local_sources()) do
    if vim.fn.isdirectory(source) == 1 then
      if path_matches_repo(source, repo) then
        return source
      end

      local nested = source .. "/" .. repo_name
      if vim.fn.isdirectory(nested) == 1 and path_matches_repo(nested, repo) then
        return nested
      end
    end
  end

  return nil
end

local function resolve_theme_source()
  local local_repo = resolve_local_repo_path(theme_repo)
  if local_repo then
    return {
      dir = local_repo,
      name = theme_plugin_name,
    }
  end

  local ok_theme_browser, theme_browser = pcall(require, "theme-browser")
  local ok_github, github = pcall(require, "theme-browser.downloader.github")
  if ok_theme_browser and ok_github and type(theme_browser.get_config) == "function" then
    local config = theme_browser.get_config()
    local cache_dir = type(config) == "table" and config.cache_dir or nil
    if type(cache_dir) == "string" and cache_dir ~= "" then
      local cache_path = nil
      if type(github.resolve_cache_path) == "function" then
        cache_path = github.resolve_cache_path(theme_repo, cache_dir)
      elseif type(github.get_cache_path) == "function" then
        cache_path = github.get_cache_path(theme_repo, cache_dir)
      end
      if type(cache_path) == "string" and cache_path ~= "" and vim.fn.isdirectory(cache_path) == 1 then
        return {
          dir = cache_path,
          name = theme_plugin_name,
        }
      end
    end
  end

  local _, repo_name = theme_repo:match("([^/]+)/(.+)")
  if type(repo_name) == "string" and repo_name ~= "" then
    local lazy_path = vim.fn.stdpath("data") .. "/lazy/" .. repo_name
    if vim.fn.isdirectory(lazy_path) == 1 and path_matches_repo(lazy_path, theme_repo) then
      return {
        dir = lazy_path,
        name = theme_plugin_name,
      }
    end
  end

  return {
    [1] = theme_repo,
    name = theme_plugin_name,
  }
end

local function is_browser_enabled()
  local ok_state, state = pcall(require, "theme-browser.persistence.state")
  if ok_state and type(state.get_browser_enabled) == "function" then
    return state.get_browser_enabled()
  end
  return true
end

local source = resolve_theme_source()
return {
  vim.tbl_extend("force", source, {
    repo = theme_repo,
    dependencies = { "rktjmp/lush.nvim" },
    lazy = false,
    priority = 2000,
    config = function()
      if not is_browser_enabled() then
        return
      end

      if vim.g.colors_name == "%s" then
        return
      end

      local ok_base, base = pcall(require, "theme-browser.adapters.base")
      local ok_state, state = pcall(require, "theme-browser.persistence.state")
      local current = ok_state and state.get_current_theme and state.get_current_theme() or nil
      if ok_base and current and current.name then
        local result = base.load_theme(current.name, current.variant, { notify = false, persist_startup = false })
        if result and result.ok then
          return
        end
      end
      pcall(vim.cmd.colorscheme, "%s")
    end,
  }),
}
]],
    theme_repo,
    plugin_name,
    local_sources_literal,
    colorscheme,
    colorscheme
  )
end

---Generate LazyVim spec file
---@param theme_name string Theme name
---@param variant string|nil Theme variant
---@param opts table|nil { notify:boolean|nil, update_state:boolean|nil }
function M.generate_spec(theme_name, variant, opts)
  opts = opts or {}
  local notify = opts.notify
  if notify == nil then
    notify = true
  end
  local update_state = opts.update_state
  if update_state == nil then
    update_state = true
  end

  local registry = require("theme-browser.adapters.registry")
  local entry = registry.resolve(theme_name, variant)

  if not entry then
    log.warn(string.format("Theme '%s' not found in registry", theme_name))
    return nil
  end

  local spec_file = get_spec_file()
  ensure_parent_dir(spec_file)

  local local_sources = configured_local_repo_sources()
  local spec_content = build_spec_content(entry, entry.colorscheme or entry.name, local_sources)
  local file = io.open(spec_file, "w")
  if not file then
    log.error(string.format("Failed to write spec to: %s", spec_file))
    return nil
  end

  file:write(spec_content)
  file:close()

  local legacy_spec_file = get_legacy_spec_file()
  if legacy_spec_file ~= spec_file and vim.fn.filereadable(legacy_spec_file) == 1 then
    vim.fn.delete(legacy_spec_file)
  end

  if update_state then
    local state = require("theme-browser.persistence.state")
    state.set_current_theme(entry.name, entry.variant)
  end

  if notify then
    log.info(string.format("LazyVim spec written to: %s", spec_file))
  end
  return spec_file
end

---Detect if lazy.nvim is available
---@return boolean
function M.has_lazy()
  return package.loaded["lazy"] ~= nil or pcall(require, "lazy")
end

---Get current LazyVim spec state
---@return table|nil current spec theme
function M.get_current_spec()
  local spec_file = resolve_existing_spec_file()
  local content = read_spec_content(spec_file)
  if not content then
    return nil
  end

  local repo = extract_repo(content)
  if not repo then
    return nil
  end

  local registry = require("theme-browser.adapters.registry")
  local themes = registry.list_themes()
  for _, theme in ipairs(themes) do
    if theme.repo == repo then
      return theme
    end
  end

  return nil
end

---@return boolean
function M.has_managed_spec()
  return vim.fn.filereadable(get_spec_file()) == 1 or vim.fn.filereadable(get_legacy_spec_file()) == 1
end

---Migrate legacy managed spec to cache-aware template when possible.
---Safe and idempotent: no rewrite when already migrated or unresolved.
---@param opts table|nil {notify:boolean|nil}
---@return table {migrated:boolean, reason:string, spec_file:string|nil}
function M.migrate_to_cache_aware(opts)
  opts = opts or {}

  local spec_file = resolve_existing_spec_file()
  local content = read_spec_content(spec_file)
  if not content then
    return { migrated = false, reason = "missing", spec_file = nil }
  end

  if is_cache_aware_content(content) and spec_file == get_spec_file() then
    return { migrated = false, reason = "already_cache_aware", spec_file = spec_file }
  end

  local repo = extract_repo(content)
  local theme = resolve_theme_from_repo(repo)
  if not theme or type(theme.name) ~= "string" or theme.name == "" then
    return { migrated = false, reason = "unresolved_theme", spec_file = spec_file }
  end

  local generated = M.generate_spec(theme.name, theme.variant, {
    notify = opts.notify == true,
    update_state = false,
  })
  if not generated then
    return { migrated = false, reason = "write_failed", spec_file = spec_file }
  end

  return { migrated = true, reason = "migrated", spec_file = generated }
end

---Remove LazyVim spec
---@param opts table|nil {notify:boolean|nil}
function M.remove_spec(opts)
  opts = opts or {}
  local notify = opts.notify
  if notify == nil then
    notify = true
  end

  local removed = false
  local files = { get_spec_file(), get_legacy_spec_file() }
  local seen = {}

  for _, spec_file in ipairs(files) do
    if not seen[spec_file] then
      seen[spec_file] = true
      if vim.fn.filereadable(spec_file) == 1 then
        vim.fn.delete(spec_file)
        removed = true
      end
    end
  end

  if notify and removed then
    log.info("LazyVim spec removed")
  end
end

return M
