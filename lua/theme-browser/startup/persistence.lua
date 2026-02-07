local M = {}

local startup_config = require("theme-browser.startup.config")

local function safe_require(name)
  local ok, mod = pcall(require, name)
  if ok then
    return mod
  end
  return nil
end

local function resolve_entry(theme_name, variant)
  local registry = safe_require("theme-browser.adapters.registry")
  if not registry or type(registry.resolve) ~= "function" then
    return nil
  end
  return registry.resolve(theme_name, variant)
end

local function build_startup_metadata(theme_name, variant, colorscheme)
  local metadata = {
    name = theme_name,
    variant = variant,
    colorscheme = colorscheme,
    repo = nil,
  }

  local entry = resolve_entry(theme_name, variant)
  if not entry then
    return metadata
  end

  metadata.name = entry.name or metadata.name
  metadata.variant = entry.variant
  metadata.colorscheme = entry.colorscheme or metadata.colorscheme or entry.name
  metadata.repo = entry.repo
  return metadata
end

local function persist_startup_state(metadata)
  local state = safe_require("theme-browser.persistence.state")
  if not state or type(state.set_startup_theme) ~= "function" then
    return
  end
  state.set_startup_theme(metadata)
end

local function write_startup_spec(theme_name, variant)
  local lazy_spec = safe_require("theme-browser.persistence.lazy_spec")
  if not lazy_spec or type(lazy_spec.generate_spec) ~= "function" then
    return
  end

  lazy_spec.generate_spec(theme_name, variant, {
    notify = false,
    update_state = false,
  })
end

---@param theme_name string
---@param variant string|nil
---@param colorscheme string|nil
---@param opts table|nil
function M.persist_applied_theme(theme_name, variant, colorscheme, opts)
  opts = opts or {}
  if opts.preview or opts.persist_startup == false then
    return
  end

  local startup = startup_config.from_runtime()
  if not startup.enabled then
    return
  end

  local metadata = build_startup_metadata(theme_name, variant, colorscheme)
  persist_startup_state(metadata)

  if startup.write_spec then
    write_startup_spec(theme_name, variant)
  end
end

return M
