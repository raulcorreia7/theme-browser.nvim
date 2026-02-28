local M = {}

local _snapshots = {}
local _runtimepath_before

local function get_plugin_root()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  local absolute = vim.fn.fnamemodify(source, ":p")
  return vim.fn.fnamemodify(absolute, ":h:h:h")
end

function M.snapshot(modules)
  if type(modules) == "string" then
    modules = { modules }
  end
  local snap = {}
  for _, name in ipairs(modules) do
    snap[name] = package.loaded[name]
  end
  table.insert(_snapshots, snap)
  return snap
end

function M.restore(snapshots)
  if type(snapshots) ~= "table" then
    return
  end
  for name, mod in pairs(snapshots) do
    if mod == nil then
      package.loaded[name] = nil
    else
      package.loaded[name] = mod
    end
  end
end

function M.reset_all(modules)
  _snapshots = {}
  _runtimepath_before = vim.o.runtimepath
  if modules then
    for _, name in ipairs(modules) do
      M.snapshot(name)
      package.loaded[name] = nil
    end
  else
    for key in pairs(package.loaded) do
      if key:match("^theme%-browser") then
        package.loaded[key] = nil
      end
    end
  end
end

function M.restore_all(modules)
  if _runtimepath_before then
    vim.o.runtimepath = _runtimepath_before
  end
  if modules then
    for _, name in ipairs(modules) do
      M.restore({ [name] = _snapshots[#_snapshots] and _snapshots[#_snapshots][name] })
    end
  else
    for i = #_snapshots, 1, -1 do
      M.restore(_snapshots[i])
    end
  end
end

function M.with_clean_state(modules, fn)
  local snap = M.snapshot(modules)
  for _, name in ipairs(modules) do
    package.loaded[name] = nil
  end
  local ok, err = pcall(fn)
  M.restore(snap)
  if not ok then
    error(err, 0)
  end
end

function M.spy_on(tbl, key)
  local original = tbl[key]
  local calls = {}
  local spy = function(...)
    table.insert(calls, { args = { ... } })
    if type(original) == "function" then
      return original(...)
    end
    return original
  end
  tbl[key] = spy
  return {
    calls = calls,
    restore = function()
      tbl[key] = original
    end,
    count = function()
      return #calls
    end,
  }
end

function M.stub(tbl, key, fn)
  local original = tbl[key]
  tbl[key] = fn
  return {
    restore = function()
      tbl[key] = original
    end,
  }
end

function M.mock_vim_notify()
  local original = vim.notify
  local calls = {}
  local mock = function(msg, level, opts)
    table.insert(calls, {
      message = msg,
      level = level,
      opts = opts,
    })
  end
  vim.notify = mock
  return {
    calls = calls,
    restore = function()
      vim.notify = original
    end,
    get = function()
      return calls
    end,
    has_warning = function(pattern)
      for _, c in ipairs(calls) do
        if c.level == vim.log.levels.WARN and c.message:match(pattern) then
          return true
        end
      end
      return false
    end,
  }
end

local plugin_root = get_plugin_root()

function M.get_fixture_path(name)
  local lua_path = plugin_root .. "/tests/helpers/fixtures/" .. name .. ".lua"
  if vim.fn.filereadable(lua_path) == 1 then
    return lua_path
  end
  local json_path = plugin_root .. "/tests/helpers/fixtures/" .. name .. ".json"
  if vim.fn.filereadable(json_path) == 1 then
    return json_path
  end
  return M.get_bundled_registry_path()
end

function M.get_bundled_registry_path()
  local candidates = {
    plugin_root,
    vim.env.THEME_BROWSER_PLUGIN_ROOT,
    vim.fn.getcwd(),
  }

  for _, root in ipairs(candidates) do
    if root and root ~= "" then
      local bundled = root .. "/lua/theme-browser/data/registry.json"
      if vim.fn.filereadable(bundled) == 1 then
        return bundled
      end
      bundled = root .. "/lua/theme-browser/data/themes-top-50.json"
      if vim.fn.filereadable(bundled) == 1 then
        return bundled
      end
    end
  end

  return nil
end

function M.setup_with_registry(fixture_name)
  M.reset_all()
  local registry_path
  if fixture_name then
    local ok, fixtures = pcall(require, "tests.helpers.fixtures.registry")
    if ok and fixtures[fixture_name] and fixtures.write_fixture then
      registry_path = fixtures.write_fixture(fixture_name, fixture_name)
    else
      registry_path = M.get_fixture_path(fixture_name)
    end
  else
    registry_path = M.get_bundled_registry_path()
  end
  local tb = require("theme-browser")
  tb.setup({ registry_path = registry_path })
  return tb
end

function M.assert_theme_applied(name, variant)
  local colors_name = vim.g.colors_name
  if variant then
    assert.are.equal(
      variant,
      colors_name,
      string.format("Expected colorscheme %s, got %s", variant, tostring(colors_name))
    )
  else
    assert.is_true(
      colors_name == name or (colors_name and colors_name:find(name, 1, true) == 1),
      string.format("Expected colorscheme matching %s, got %s", name, tostring(colors_name))
    )
  end
end

function M.assert_state_persisted(state_module, name, variant)
  local current = state_module.get_current_theme()
  assert.is_not_nil(current, "Expected current theme to be persisted")
  assert.are.equal(name, current.name, string.format("Expected theme name %s, got %s", name, current.name))
  if variant then
    assert.are.equal(
      variant,
      current.variant,
      string.format("Expected variant %s, got %s", variant, current.variant)
    )
  end
end

function M.make_theme_entry(name, opts)
  opts = opts or {}
  local entry = {
    name = name,
    colorscheme = opts.colorscheme or name,
    repo = opts.repo or ("owner/" .. name .. ".nvim"),
  }
  if opts.variant then
    entry.variant = opts.variant
  end
  if opts.mode then
    entry.mode = opts.mode
  end
  if opts.builtin then
    entry.builtin = true
  end
  if opts.source then
    entry.source = opts.source
  end
  if opts.strategy then
    entry.strategy = opts.strategy
  end
  if opts.module then
    entry.module = opts.module
  end
  if opts.variants then
    entry.variants = opts.variants
  end
  if opts.meta then
    entry.meta = opts.meta
  end
  if opts.id then
    entry.id = opts.id
  end
  return entry
end

function M.make_builtin_theme(name)
  return {
    name = name,
    colorscheme = name,
    source = "neovim",
  }
end

function M.make_plugin_theme(name, repo, variants)
  return {
    name = name,
    colorscheme = name,
    repo = repo,
    strategy = "setup",
    module = name,
    variants = variants,
  }
end

function M.with_temp_registry(content, fn)
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")
  local tb_module = "theme-browser"
  local original_tb = package.loaded[tb_module]
  package.loaded[tb_module] = {
    get_config = function()
      return { cache_dir = temp_dir }
    end,
  }

  local path
  if content then
    path = temp_dir .. "/registry.json"
    local encoded = type(content) == "string" and content or vim.json.encode(content)
    vim.fn.writefile({ encoded }, path)
  end

  local ok, err = pcall(fn, path or temp_dir)

  package.loaded[tb_module] = original_tb
  vim.fn.delete(temp_dir, "rf")

  if not ok then
    error(err, 0)
  end
end

function M.write_registry(themes)
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")
  local path = temp_dir .. "/registry.json"
  vim.fn.writefile({ vim.json.encode(themes) }, path)
  return path, temp_dir
end

function M.create_test_config(opts)
  opts = opts or {}
  local temp_dir = vim.fn.tempname()
  return vim.tbl_extend("force", {
    registry_path = opts.registry_path or M.get_bundled_registry_path(),
    cache_dir = opts.cache_dir or temp_dir,
    auto_load = opts.auto_load or false,
    package_manager = opts.package_manager or {
      enabled = false,
      mode = "manual",
      provider = "noop",
    },
  }, opts)
end

function M.mock_vim_system(responses)
  local call_count = 0
  return function(_cmd, _opts, callback)
    call_count = call_count + 1
    local response = responses[call_count] or responses[#responses]
    if callback then
      vim.schedule(function()
        callback(response)
      end)
    end
  end
end

function M.wait_for_result(timeout_ms)
  timeout_ms = timeout_ms or 2000
  local start = vim.loop.hrtime()
  local result = nil

  while not result do
    local elapsed = (vim.loop.hrtime() - start) / 1e6
    if elapsed > timeout_ms then
      return nil, "timeout"
    end
    vim.wait(10)
  end

  return result
end

function M.wait_for_callback(callback, timeout_ms)
  timeout_ms = timeout_ms or 2000
  local called = false
  local result = nil
  local wrapper = function(...)
    called = true
    result = { ... }
  end
  return wrapper,
    function()
      vim.wait(timeout_ms, function()
        return called
      end)
      return called, result
    end
end

return M
