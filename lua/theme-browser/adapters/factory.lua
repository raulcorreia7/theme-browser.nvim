local M = {}
local plugin_adapters = require("theme-browser.adapters.plugins")
local registry = require("theme-browser.adapters.registry")

local STRATEGIES = {
  colorscheme = true,
  setup = true,
  load = true,
  file = true,
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

local function apply_vim_options(entry)
  local strategy = entry.meta and entry.meta.strategy
  local vim_opts = strategy and strategy.vim

  if type(vim_opts) ~= "table" then
    return
  end

  if type(vim_opts.o) == "table" then
    for key, value in pairs(vim_opts.o) do
      if type(key) == "string" and key ~= "" then
        vim.o[key] = value
      end
    end
  end

  if type(vim_opts.g) == "table" then
    for key, value in pairs(vim_opts.g) do
      if type(key) == "string" and key ~= "" then
        vim.g[key] = value
      end
    end
  end
end

local function resolve_strategy_type(entry)
  local strategy = entry.meta and entry.meta.strategy
  if strategy and strategy.type and STRATEGIES[strategy.type] then
    return strategy.type
  end
  return "colorscheme"
end

local function resolve_module_name(entry)
  local strategy = entry.meta and entry.meta.strategy
  if strategy and type(strategy.module) == "string" and strategy.module ~= "" then
    return strategy.module
  end
  return entry.name
end

local function resolve_opts(entry)
  local strategy = entry.meta and entry.meta.strategy
  if strategy and type(strategy.opts) == "table" then
    return strategy.opts
  end
  return {}
end

local function resolve_args(entry)
  local strategy = entry.meta and entry.meta.strategy
  if strategy and type(strategy.args) == "table" then
    return strategy.args
  end
  return {}
end

local function resolve_mode(entry)
  if entry.mode then
    return entry.mode
  end
  local meta = entry.meta
  if meta then
    if meta.mode then
      return meta.mode
    end
    if meta.strategy and meta.strategy.mode then
      return meta.strategy.mode
    end
  end
  return nil
end

-- Common keys used by themes to specify the variant/theme in setup()
local VARIANT_KEYS = { "theme", "style", "colorscheme", "variant", "flavour", "flavor" }

local function resolve_variant_opts(entry, base_opts)
  if not entry.variant then
    return base_opts
  end

  -- Check if any variant key is already set in opts
  for _, key in ipairs(VARIANT_KEYS) do
    if base_opts[key] then
      return base_opts
    end
  end

  -- Check if any variant key is specified in meta.strategy
  local strategy = entry.meta and entry.meta.strategy
  if strategy then
    for _, key in ipairs(VARIANT_KEYS) do
      if strategy[key] then
        return vim.tbl_extend("force", base_opts, { [key] = strategy[key] })
      end
    end
  end

  -- Try each common key to see which one the theme accepts
  -- Start with "theme" as it's most common
  return vim.tbl_extend("force", base_opts, { theme = entry.variant })
end

local function load_with_setup(entry)
  apply_vim_options(entry)
  local module_name = resolve_module_name(entry)
  local module, require_err = safe_require(module_name)

  if module and type(module.setup) == "function" then
    local opts = resolve_opts(entry)
    -- For variant themes, pass the variant/theme name to setup
    -- This is needed for themes like astrotheme that require setup({ theme = "variant" })
    opts = resolve_variant_opts(entry, opts)
    pcall(module.setup, opts)
  end

  local ok, cs_err, applied, tried = apply_colorscheme(entry)
  return ok,
    {
      applied_colorscheme = applied,
      tried_colorschemes = table.concat(tried or {}, ","),
      require_error = require_err,
      colorscheme_error = cs_err,
    }
end

local function load_with_load(entry)
  apply_vim_options(entry)
  local module_name = resolve_module_name(entry)
  local module, require_err = safe_require(module_name)

  if module then
    if type(module.setup) == "function" then
      pcall(module.setup, resolve_opts(entry))
    end

    local candidate = nil
    if type(module.load) == "function" then
      candidate = module.load
    elseif type(module.set) == "function" then
      candidate = module.set
    end

    if candidate then
      local args = resolve_args(entry)
      if #args > 0 then
        pcall(candidate, unpack(args))
      else
        pcall(candidate, entry.colorscheme or entry.variant)
      end
    end
  end

  local ok, cs_err, applied, tried = apply_colorscheme(entry)
  return ok,
    {
      applied_colorscheme = applied,
      tried_colorschemes = table.concat(tried or {}, ","),
      require_error = require_err,
      colorscheme_error = cs_err,
    }
end

local function load_with_colorscheme(entry)
  apply_vim_options(entry)
  local ok, err, applied, tried = apply_colorscheme(entry)
  return ok,
    {
      applied_colorscheme = applied,
      tried_colorschemes = table.concat(tried or {}, ","),
      colorscheme_error = err,
    }
end

local function load_with_file(entry)
  local strategy = entry.meta and entry.meta.strategy
  local file_path = strategy and strategy.file

  if not file_path or file_path == "" then
    return load_with_colorscheme(entry)
  end

  apply_vim_options(entry)

  local ok, err = pcall(dofile, file_path)
  if not ok then
    return load_with_colorscheme(entry)
  end

  return true, {
    colorscheme_error = err,
  }
end

local function build_result(entry, strategy_type, ok, errors)
  local result = {
    ok = ok,
    name = entry.name,
    variant = entry.variant,
    mode = resolve_mode(entry),
    id = entry.id,
    strategy = strategy_type,
    colorscheme = colorscheme_from_entry(entry),
    fallback = strategy_type ~= "colorscheme",
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
  local strategy_type = resolve_strategy_type(entry)
  return {
    adapter_type = strategy_type,
    load = function(target_entry)
      local ok
      local errors

      if strategy_type == "setup" then
        ok, errors = load_with_setup(target_entry)
      elseif strategy_type == "load" then
        ok, errors = load_with_load(target_entry)
      elseif strategy_type == "file" then
        ok, errors = load_with_file(target_entry)
      else
        ok, errors = load_with_colorscheme(target_entry)
      end

      return build_result(target_entry, strategy_type, ok, errors)
    end,
  }
end

function M.load_theme(theme_name, variant)
  local entry = registry.resolve(theme_name, variant)

  if not entry then
    return {
      ok = false,
      name = theme_name,
      variant = variant,
      strategy = "colorscheme",
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
  return M.load_theme(theme_name, variant)
end

function M.get_theme_status(theme_name)
  local entry = registry.resolve(theme_name)
  if not entry then
    return {
      installed = false,
      adapter_type = "colorscheme",
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
    adapter_type = resolve_strategy_type(entry),
    variants = #variants > 0 and variants or nil,
  }
end

return M
