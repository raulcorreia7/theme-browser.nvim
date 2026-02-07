describe("Integration: setup autoload", function()
  local theme_browser_module = "theme-browser"
  local command_names = {
    "ThemeBrowser",
    "ThemeBrowserFocus",
    "ThemeBrowserTheme",
    "ThemeBrowserStatus",
    "ThemeBrowserMark",
    "ThemeBrowserClean",
    "ThemeBrowserCacheClear",
    "ThemeBrowserCacheInfo",
    "ThemeBrowserPreview",
    "ThemeBrowserInstall",
    "ThemeBrowserUninstall",
    "ThemeBrowserReset",
    "ThemeBrowserHelp",
  }

  local snapshots = {}

  local function snapshot_module(name)
    snapshots[name] = package.loaded[name]
  end

  local function restore_module(name)
    local previous = snapshots[name]
    if previous == nil then
      package.loaded[name] = nil
    else
      package.loaded[name] = previous
    end
  end

  local function clear_commands()
    for _, command in ipairs(command_names) do
      pcall(vim.api.nvim_del_user_command, command)
    end
  end

  local function with_test_cache(opts)
    local config = vim.deepcopy(opts or {})
    local cache = type(config.cache) == "table" and config.cache or {}
    config.cache = vim.tbl_extend("force", { auto_cleanup = false }, cache)
    return config
  end

  before_each(function()
    snapshots = {}
    snapshot_module(theme_browser_module)
    snapshot_module("theme-browser.persistence.state")
    snapshot_module("theme-browser.adapters.registry")
    snapshot_module("theme-browser.adapters.base")
    snapshot_module("theme-browser.package_manager.manager")

    package.loaded[theme_browser_module] = nil
    clear_commands()
  end)

  after_each(function()
    package.loaded[theme_browser_module] = nil
    restore_module("theme-browser.persistence.state")
    restore_module("theme-browser.adapters.registry")
    restore_module("theme-browser.adapters.base")
    restore_module("theme-browser.package_manager.manager")
    restore_module(theme_browser_module)
    clear_commands()
  end)

  it("auto-loads persisted theme when enabled", function()
    local called = nil

    package.loaded["theme-browser.persistence.state"] = {
      initialize = function(_) end,
      get_current_theme = function()
        return { name = "tokyonight", variant = "tokyonight-night" }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function(_) end,
      resolve = function(_, _)
        return { name = "tokyonight", variant = "tokyonight-night" }
      end,
      list_themes = function()
        return {}
      end,
    }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(name, variant, opts)
        called = { name = name, variant = variant, opts = opts }
        return { ok = true, name = name, variant = variant, colorscheme = variant }
      end,
      has_package_manager = function()
        return true
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(callback)
        callback()
      end,
    }

    local tb = require(theme_browser_module)
    tb.setup(with_test_cache({ auto_load = true }))

    assert.is_not_nil(called)
    assert.equals("tokyonight", called.name)
    assert.equals("tokyonight-night", called.variant)
    assert.is_true(type(called.opts) == "table")
    assert.is_false(called.opts.notify)
  end)

  it("does not auto-load when disabled", function()
    local called = false

    package.loaded["theme-browser.persistence.state"] = {
      initialize = function(_) end,
      get_current_theme = function()
        return { name = "tokyonight", variant = "tokyonight-night" }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function(_) end,
      resolve = function(_, _)
        return nil
      end,
      list_themes = function()
        return {}
      end,
    }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        called = true
      end,
      has_package_manager = function()
        return true
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(callback)
        callback()
      end,
    }

    local tb = require(theme_browser_module)
    tb.setup(with_test_cache({ auto_load = false }))

    assert.is_false(called)
  end)

  it("does not warn or load when persisted theme is not in registry", function()
    local called = false
    local notified = false
    local original_notify = vim.notify

    vim.notify = function(_, _, _)
      notified = true
    end

    package.loaded["theme-browser.persistence.state"] = {
      initialize = function(_) end,
      get_current_theme = function()
        return { name = "different-theme", variant = nil }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function(_) end,
      resolve = function(_, _)
        return nil
      end,
      list_themes = function()
        return {}
      end,
    }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        called = true
      end,
      has_package_manager = function()
        return true
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(callback)
        callback()
      end,
    }

    local tb = require(theme_browser_module)
    tb.setup(with_test_cache({ auto_load = true }))

    vim.notify = original_notify
    assert.is_false(called)
    assert.is_false(notified)
  end)

  it("registers clean command surface", function()
    package.loaded["theme-browser.persistence.state"] = {
      initialize = function(_) end,
      get_current_theme = function()
        return nil
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function(_) end,
      resolve = function(_, _)
        return nil
      end,
      list_themes = function()
        return {}
      end,
    }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        return { ok = true }
      end,
      has_package_manager = function()
        return true
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(callback)
        callback()
      end,
    }

    local tb = require(theme_browser_module)
    tb.setup(with_test_cache({ auto_load = false }))

    assert.equals(2, vim.fn.exists(":ThemeBrowserReset"))
    assert.equals(2, vim.fn.exists(":ThemeBrowserClean"))
    assert.equals(0, vim.fn.exists(":ThemeBrowserPreviewAll"))
    assert.equals(0, vim.fn.exists(":ThemeBrowserCacheDelete"))
    assert.equals(0, vim.fn.exists(":ThemeBrowserCachePurge"))
  end)

  it("passes optional variant to ThemeBrowserMark command", function()
    local marked = nil

    package.loaded["theme-browser.persistence.state"] = {
      initialize = function(_) end,
      get_current_theme = function()
        return nil
      end,
      mark_theme = function(name, variant)
        marked = { name = name, variant = variant }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function(_) end,
      resolve = function(_, _)
        return nil
      end,
      list_themes = function()
        return {}
      end,
    }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        return { ok = true }
      end,
      has_package_manager = function()
        return true
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(callback)
        callback()
      end,
    }

    local tb = require(theme_browser_module)
    tb.setup(with_test_cache({ auto_load = false }))

    vim.cmd("ThemeBrowserMark tokyonight night")

    assert.is_not_nil(marked)
    assert.equals("tokyonight", marked.name)
    assert.equals("night", marked.variant)
  end)

  it("falls back to current editor colorscheme when state is empty", function()
    local set_current_called = nil
    local original_colors_name = vim.g.colors_name
    vim.g.colors_name = "everforest"

    package.loaded["theme-browser.persistence.state"] = {
      initialize = function(_) end,
      get_current_theme = function()
        return nil
      end,
      set_current_theme = function(name, variant)
        set_current_called = { name = name, variant = variant }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function(_) end,
      get_entry = function(id)
        if id == "everforest" then
          return { name = "everforest", variant = "dark" }
        end
        return nil
      end,
      resolve = function(_, _)
        return nil
      end,
      list_themes = function()
        return {}
      end,
    }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        return { ok = true }
      end,
      has_package_manager = function()
        return true
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(callback)
        callback()
      end,
    }

    local tb = require(theme_browser_module)
    tb.setup(with_test_cache({ auto_load = false }))

    vim.g.colors_name = original_colors_name
    assert.is_not_nil(set_current_called)
    assert.equals("everforest", set_current_called.name)
    assert.equals("dark", set_current_called.variant)
  end)

  it("defers auto-load until package manager is ready", function()
    local called = false
    local deferred = nil

    package.loaded["theme-browser.persistence.state"] = {
      initialize = function(_) end,
      get_current_theme = function()
        return { name = "tokyonight", variant = "tokyonight-night" }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function(_) end,
      resolve = function(_, _)
        return { name = "tokyonight", variant = "tokyonight-night" }
      end,
      list_themes = function()
        return {}
      end,
    }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        called = true
        return { ok = true }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(callback)
        deferred = callback
      end,
    }

    local tb = require(theme_browser_module)
    tb.setup(with_test_cache({ auto_load = true }))

    assert.is_false(called)
    assert.is_true(type(deferred) == "function")

    deferred()
    assert.is_true(called)
  end)

  it("skips startup auto-load when target colorscheme is already active", function()
    local called = false
    local original_colors_name = vim.g.colors_name
    vim.g.colors_name = "tokyonight-night"

    package.loaded["theme-browser.persistence.state"] = {
      initialize = function(_) end,
      get_current_theme = function()
        return { name = "tokyonight", variant = "tokyonight-night" }
      end,
      get_startup_theme = function()
        return { colorscheme = "tokyonight-night" }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function(_) end,
      resolve = function(_, _)
        return {
          name = "tokyonight",
          variant = "tokyonight-night",
          colorscheme = "tokyonight-night",
        }
      end,
      list_themes = function()
        return {}
      end,
    }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        called = true
        return { ok = true }
      end,
      has_package_manager = function()
        return true
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(callback)
        callback()
      end,
    }

    local tb = require(theme_browser_module)
    tb.setup(with_test_cache({
      auto_load = true,
      startup = { skip_if_already_active = true },
    }))

    vim.g.colors_name = original_colors_name
    assert.is_false(called)
  end)
end)
