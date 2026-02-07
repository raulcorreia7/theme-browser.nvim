local M = {}
local plugin_adapters = require("theme-browser.adapters.plugins")

local VALID_STRATEGIES = {
  colorscheme_only = true,
  setup_colorscheme = true,
  setup_load = true,
  vimg_colorscheme = true,
}

local function safe_require(module_name)
  if type(module_name) ~= "string" or module_name == "" then
    return nil, "module name missing"
  end

  local ok, module = pcall(require, module_name)
  if not ok then
    return nil, module
  end

  return module, nil
end

local function colorscheme_from_entry(entry)
  return entry.colorscheme or entry.name
end

local function candidate_colorschemes(entry)
  local candidates = {}
  local seen = {}

  local function add(value)
    if type(value) == "string" and value ~= "" and not seen[value] then
      seen[value] = true
      table.insert(candidates, value)
    end
  end

  add(entry.colorscheme)
  if entry.variant then
    add(entry.variant)
    if entry.name then
      add(string.format("%s-%s", entry.name, entry.variant))
    end
  end
  add(entry.name)

  return candidates
end

local function apply_colorscheme(entry)
  local tried = candidate_colorschemes(entry)
  local last_err = nil

  for _, cs in ipairs(tried) do
    local ok, err = pcall(vim.cmd.colorscheme, cs)
    if ok then
      return true, nil, cs, tried
    end
    last_err = err
  end

  return false, last_err, colorscheme_from_entry(entry), tried
end

local function apply_editor_options(entry)
  if type(entry.meta) ~= "table" then
    return
  end

  if type(entry.meta.opts_o) == "table" then
    for key, value in pairs(entry.meta.opts_o) do
      if type(key) == "string" and key ~= "" then
        vim.o[key] = value
      end
    end
  end

  if type(entry.meta.opts_g) == "table" then
    for key, value in pairs(entry.meta.opts_g) do
      if type(key) == "string" and key ~= "" then
        vim.g[key] = value
      end
    end
  end
end

local function resolve_strategy(entry)
  local strategy = "colorscheme_only"
  if entry and entry.meta and VALID_STRATEGIES[entry.meta.strategy] then
    strategy = entry.meta.strategy
  end
  return strategy
end

local function resolve_module_name(entry)
  if entry.meta and type(entry.meta.module) == "string" and entry.meta.module ~= "" then
    return entry.meta.module
  end
  return entry.name
end

local function load_with_setup_colorscheme(entry)
  apply_editor_options(entry)
  local module_name = resolve_module_name(entry)
  local module, require_err = safe_require(module_name)

  if module and type(module.setup) == "function" then
    pcall(module.setup, entry.meta and entry.meta.opts or {})
  end

  local ok, cs_err, applied, tried = apply_colorscheme(entry)
  return ok, {
    applied_colorscheme = applied,
    tried_colorschemes = table.concat(tried or {}, ","),
    require_error = require_err,
    colorscheme_error = cs_err,
  }
end

local function load_with_setup_load(entry)
  apply_editor_options(entry)
  local module_name = resolve_module_name(entry)
  local module, require_err = safe_require(module_name)

  if module then
    local candidate = nil
    if type(module.load) == "function" then
      candidate = module.load
    elseif type(module.set) == "function" then
      candidate = module.set
    end

    if candidate then
      pcall(candidate, entry.colorscheme or entry.variant)
    end
  end

  local ok, cs_err, applied, tried = apply_colorscheme(entry)
  return ok, {
    applied_colorscheme = applied,
    tried_colorschemes = table.concat(tried or {}, ","),
    require_error = require_err,
    colorscheme_error = cs_err,
  }
end

local function load_with_vimg_colorscheme(entry)
  apply_editor_options(entry)

  local ok, err, applied, tried = apply_colorscheme(entry)
  return ok, {
    applied_colorscheme = applied,
    tried_colorschemes = table.concat(tried or {}, ","),
    colorscheme_error = err,
  }
end

local function load_with_colorscheme_only(entry)
  apply_editor_options(entry)
  local ok, err, applied, tried = apply_colorscheme(entry)
  return ok, {
    applied_colorscheme = applied,
    tried_colorschemes = table.concat(tried or {}, ","),
    colorscheme_error = err,
  }
end

local function build_result(entry, strategy, ok, errors)
  local result = {
    ok = ok,
    name = entry.name,
    variant = entry.variant,
    id = entry.id,
    strategy = strategy,
    colorscheme = colorscheme_from_entry(entry),
    fallback = strategy ~= "colorscheme_only",
    errors = {},
  }

  if errors then
    for key, value in pairs(errors) do
      if value then
        result.errors[key] = tostring(value)
      end
    end
  end

  return result
end

function M.get_adapter(entry)
  local strategy = resolve_strategy(entry)
  return {
    adapter_type = strategy,
    load = function(target_entry)
      local ok
      local errors

      if strategy == "setup_colorscheme" then
        ok, errors = load_with_setup_colorscheme(target_entry)
      elseif strategy == "setup_load" then
        ok, errors = load_with_setup_load(target_entry)
      elseif strategy == "vimg_colorscheme" then
        ok, errors = load_with_vimg_colorscheme(target_entry)
      else
        ok, errors = load_with_colorscheme_only(target_entry)
      end

      return build_result(target_entry, strategy, ok, errors)
    end,
  }
end

function M.load_theme(theme_name, variant, opts)
  local _ = opts
  local registry = require("theme-browser.adapters.registry")
  local entry = registry.resolve(theme_name, variant)

  if not entry then
    return {
      ok = false,
      name = theme_name,
      variant = variant,
      strategy = "colorscheme_only",
      colorscheme = nil,
      fallback = false,
      errors = {
        not_found = string.format("theme not found: %s", theme_name),
      },
    }
  end

  local adapted_entry = plugin_adapters.apply(entry)
  local adapter = M.get_adapter(adapted_entry)
  return adapter.load(adapted_entry)
end

function M.preview_theme(theme_name, variant)
  return M.load_theme(theme_name, variant, { preview = true, notify = false })
end

function M.get_theme_status(theme_name)
  local registry = require("theme-browser.adapters.registry")
  local entry = registry.resolve(theme_name)
  if not entry then
    return {
      installed = false,
      adapter_type = "colorscheme_only",
      variants = nil,
    }
  end

  local variants = {}
  local all_entries = registry.list_entries()
  for _, candidate in ipairs(all_entries) do
    if candidate.name == theme_name and candidate.variant then
      table.insert(variants, candidate.variant)
    end
  end

  return {
    installed = false,
    adapter_type = resolve_strategy(entry),
    variants = #variants > 0 and variants or nil,
  }
end

return M
