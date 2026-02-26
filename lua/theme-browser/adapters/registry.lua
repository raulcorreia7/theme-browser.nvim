local M = {}

---@class Theme
---@field name string
---@field repo string
---@field colorscheme string
---@field description string
---@field stars number
---@field topics string[]
---@field updated_at string
---@field archived boolean
---@field disabled boolean

local themes = {}
local entries = {}
local theme_index = {}
local entry_index = {}
local theme_alias_index = {}
local entry_alias_index = {}
local initialized = false

local function normalize_name(name)
  if type(name) ~= "string" then
    return nil
  end
  return name:lower()
end

local function normalize_token(value)
  if type(value) ~= "string" then
    return nil
  end
  local normalized = value:lower():gsub("[%s_]+", "-"):gsub("[^a-z0-9%-]", "")
  normalized = normalized:gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
  if normalized == "" then
    return nil
  end
  return normalized
end

local function repo_name(repo)
  if type(repo) ~= "string" then
    return nil
  end
  local _, name = repo:match("([^/]+)/(.+)")
  if type(name) ~= "string" then
    return nil
  end
  return name:gsub("%.git$", "")
end

local function register_theme_alias(theme, alias)
  local normalized = normalize_token(alias)
  if normalized then
    theme_alias_index[normalized] = theme
  end
end

local function register_entry_alias(entry, alias)
  local normalized = normalize_token(alias)
  if normalized and not entry_alias_index[normalized] then
    entry_alias_index[normalized] = entry
  end
end

local function clone_theme(theme)
  return vim.deepcopy(theme)
end

local function make_entry(theme, variant, colorscheme, display, extra_meta, mode)
  local entry = {
    id = variant and string.format("%s:%s", theme.name, variant) or theme.name,
    name = theme.name,
    variant = variant,
    display = display,
    repo = theme.repo,
    colorscheme = colorscheme,
    meta = vim.tbl_extend("force", theme.meta or {}, extra_meta or {}),
  }

  if mode then
    entry.mode = mode
  end

  if theme.builtin then
    entry.builtin = true
  end

  return entry
end

local function add_entry(entry)
  table.insert(entries, entry)
  entry_index[entry.id] = entry
  register_entry_alias(entry, entry.id)
  register_entry_alias(entry, entry.name)
  if entry.colorscheme then
    register_entry_alias(entry, entry.colorscheme)
  end
  if entry.variant then
    register_entry_alias(entry, string.format("%s:%s", entry.name, entry.variant))
    register_entry_alias(entry, entry.variant)
    register_entry_alias(entry, string.format("%s-%s", entry.name, entry.variant))
  end
end

local function expand_theme(theme)
  local base_colorscheme = theme.colorscheme or theme.name
  local base_display = theme.name
  local has_variants = type(theme.variants) == "table" and #theme.variants > 0

  -- Skip base entry if theme has variants
  if not has_variants then
    add_entry(make_entry(theme, nil, base_colorscheme, base_display, nil))
  end

  if not has_variants then
    return
  end

  for _, variant_def in ipairs(theme.variants) do
    if type(variant_def) == "string" then
      add_entry(make_entry(theme, variant_def, variant_def, variant_def, nil))
    elseif type(variant_def) == "table" then
      local colorscheme = variant_def.colorscheme or variant_def.name
      if type(colorscheme) == "string" and colorscheme ~= "" then
        local variant = variant_def.variant or variant_def.name or colorscheme
        local display = variant_def.name or colorscheme
        add_entry(make_entry(theme, variant, colorscheme, display, variant_def.meta, variant_def.mode))
      end
    end
  end
end

local function rebuild_indexes()
  entries = {}
  theme_index = {}
  entry_index = {}
  theme_alias_index = {}
  entry_alias_index = {}

  for _, theme in ipairs(themes) do
    if not theme.disabled and type(theme.name) == "string" then
      theme_index[theme.name] = theme
      theme_index[normalize_name(theme.name)] = theme
      register_theme_alias(theme, theme.name)
      register_theme_alias(theme, theme.colorscheme)
      register_theme_alias(theme, repo_name(theme.repo))
      if type(theme.aliases) == "table" then
        for _, alias in ipairs(theme.aliases) do
          register_theme_alias(theme, alias)
        end
      end
      expand_theme(theme)
    end
  end
end

---Initialize registry with themes.json path
---@param registry_path string Path to themes.json
function M.initialize(registry_path)
  if initialized then
    return
  end

  local file = io.open(registry_path, "r")
  if not file then
    vim.notify(
      string.format("Theme registry not found at: %s", registry_path),
      vim.log.levels.WARN
    )
    return
  end

  local content = file:read("*a")
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    vim.notify("Failed to parse theme registry JSON", vim.log.levels.ERROR)
    return
  end

  if type(decoded) ~= "table" then
    vim.notify("Theme registry must decode to a list", vim.log.levels.ERROR)
    return
  end

  themes = decoded
  rebuild_indexes()
  initialized = true
end

---Get all themes
---@return Theme[]
function M.list_themes()
  if not initialized then
    return {}
  end

  local result = {}
  for _, theme in ipairs(themes) do
    if not theme.disabled then
      table.insert(result, clone_theme(theme))
    end
  end
  return result
end

---Get all expanded entries
---@return table[]
function M.list_entries()
  if not initialized then
    return {}
  end

  local result = {}
  for _, entry in ipairs(entries) do
    table.insert(result, vim.deepcopy(entry))
  end
  return result
end

---Get theme by name
---@param name string Theme name
---@return Theme|nil
function M.get_theme(name)
  if not initialized then
    return nil
  end

  return theme_index[name]
    or theme_index[normalize_name(name)]
    or theme_alias_index[normalize_token(name)]
end

---Get expanded entry by id or "theme:variant"
---@param id string
---@return table|nil
function M.get_entry(id)
  if not initialized or type(id) ~= "string" then
    return nil
  end

  local direct = entry_index[id]
  if direct then
    return direct
  end

  local alias = entry_alias_index[normalize_token(id)]
  if alias then
    return alias
  end

  if id:find(":", 1, true) then
    local name, variant = id:match("^([^:]+):(.+)$")
    if name and variant then
      return M.resolve(name, variant)
    end
  end

  return nil
end

---Resolve entry by name and optional variant
---@param name string
---@param variant string|nil
---@return table|nil
function M.resolve(name, variant)
  if not initialized then
    return nil
  end

  local theme = M.get_theme(name)
  if not theme then
    return nil
  end

  if not variant or variant == "" then
    -- If base entry exists, return it
    local base_entry = entry_index[theme.name]
    if base_entry then
      return base_entry
    end
    -- No base entry - check if theme has variants, return first variant
    if theme.variants and #theme.variants > 0 then
      local first_variant = theme.variants[1]
      local variant_name = type(first_variant) == "string" and first_variant or first_variant.name
      return entry_index[string.format("%s:%s", theme.name, variant_name)]
    end
    return entry_alias_index[normalize_token(name)]
  end

  local entry = entry_index[string.format("%s:%s", theme.name, variant)]
  if entry then
    return entry
  end

  local by_colorscheme = entry_index[string.format("%s:%s", theme.name, (theme.colorscheme or theme.name) .. "-" .. variant)]
  if by_colorscheme then
    return by_colorscheme
  end

  local by_name_prefix = entry_index[string.format("%s:%s", theme.name, theme.name .. "-" .. variant)]
  if by_name_prefix then
    return by_name_prefix
  end

  for _, candidate in ipairs(entries) do
    if candidate.name == theme.name and (candidate.variant == variant or candidate.colorscheme == variant) then
      return candidate
    end
  end

  local alias_key = normalize_token(string.format("%s:%s", theme.name, variant))
  if alias_key and entry_alias_index[alias_key] then
    return entry_alias_index[alias_key]
  end

  local variant_alias = normalize_token(variant)
  if variant_alias then
    for _, candidate in ipairs(entries) do
      if candidate.name == theme.name then
        local c_variant = normalize_token(candidate.variant)
        local c_colorscheme = normalize_token(candidate.colorscheme)
        if c_variant == variant_alias or c_colorscheme == variant_alias then
          return candidate
        end
      end
    end
  end

  local base = entry_index[theme.name]
  if base then
    local fallback = vim.deepcopy(base)
    fallback.variant = variant
    fallback.id = string.format("%s:%s", theme.name, variant)
    fallback.display = variant
    fallback.meta = vim.tbl_extend("force", fallback.meta or {}, {
      requested_variant = variant,
    })
    return fallback
  end

  return nil
end

---Search themes by query
---@param query string Search query
---@return Theme[]
function M.search_themes(query)
  if not initialized or query == "" then
    return M.list_themes()
  end

  local query_lower = query:lower()
  local results = {}

  for _, theme in ipairs(themes) do
    if not theme.disabled then
      local description = type(theme.description) == "string" and theme.description or ""

      if theme.name:lower():find(query_lower, 1, true) or description:lower():find(query_lower, 1, true) then
        table.insert(results, theme)
      end
    end
  end

  return results
end

---Check if initialized
---@return boolean
function M.is_initialized()
  return initialized
end

return M
