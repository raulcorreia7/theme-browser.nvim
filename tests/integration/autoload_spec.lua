describe("Integration: autoload", function()
  local test_utils = require("tests.helpers.test_utils")
  local modules = {
    "theme-browser",
    "theme-browser.persistence.state",
    "theme-browser.adapters.registry",
    "theme-browser.adapters.base",
    "theme-browser.application.theme_service",
    "theme-browser.package_manager.manager",
    "theme-browser.persistence.lazy_spec",
  }
  local commands = {
    "ThemeBrowser",
    "ThemeBrowserFocus",
    "ThemeBrowserUse",
    "ThemeBrowserStatus",
    "ThemeBrowserReset",
    "ThemeBrowserHelp",
    "ThemeBrowserValidate",
    "ThemeBrowserRegistrySync",
    "ThemeBrowserRegistryClear",
    "ThemeBrowserDisable",
    "ThemeBrowserEnable",
  }

  local function clear_commands()
    for _, cmd in ipairs(commands) do
      pcall(vim.api.nvim_del_user_command, cmd)
    end
  end

  local function mock_deps(theme, load_fn, when_ready_fn)
    package.loaded["theme-browser.persistence.state"] = {
      initialize = function() end,
      get_browser_enabled = function()
        return true
      end,
      get_current_theme = function()
        return theme
      end,
      get_startup_theme = function()
        return theme and { colorscheme = theme.variant or theme.name }
      end,
    }
    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function() end,
      resolve = function()
        return theme
      end,
      list_themes = function()
        return {}
      end,
    }
    package.loaded["theme-browser.adapters.base"] = {
      load_theme = load_fn,
      has_package_manager = function()
        return true
      end,
    }
    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = when_ready_fn or function(cb)
        cb()
      end,
    }
  end

  local function setup(opts)
    local tb = require("theme-browser")
    tb.setup(vim.tbl_extend("force", {
      auto_load = false,
      cache = { auto_cleanup = false },
      startup = { write_spec = false },
    }, opts or {}))
  end

  before_each(function()
    test_utils.reset_all(modules)
    clear_commands()
  end)

  after_each(function()
    test_utils.restore_all(modules)
    clear_commands()
  end)

  it("loads persisted theme when auto_load enabled", function()
    local loaded = nil
    mock_deps({ name = "tokyonight", variant = "tokyonight-night" }, function(name, variant, opts)
      loaded = { name = name, variant = variant, opts = opts }
      return { ok = true }
    end)
    setup({ auto_load = true })
    assert.equals("tokyonight", loaded.name)
    assert.is_false(loaded.opts.notify)
  end)

  it("does not load theme when auto_load disabled", function()
    local loaded = false
    mock_deps({ name = "tokyonight" }, function()
      loaded = true
    end)
    setup({ auto_load = false })
    assert.is_false(loaded)
  end)

  it("does not load when theme not in registry", function()
    local loaded = false
    mock_deps({ name = "missing" }, function()
      loaded = true
    end)
    package.loaded["theme-browser.adapters.registry"].resolve = function()
      return nil
    end
    setup({ auto_load = true })
    assert.is_false(loaded)
  end)

  it("skips load when colorscheme already active", function()
    local loaded = false
    local orig = vim.g.colors_name
    vim.g.colors_name = "tokyonight-night"
    mock_deps({ name = "tokyonight", variant = "tokyonight-night" }, function()
      loaded = true
    end)
    setup({ auto_load = true, startup = { skip_if_already_active = true } })
    vim.g.colors_name = orig
    assert.is_false(loaded)
  end)

  it("waits for package manager before loading", function()
    local loaded = false
    local deferred = nil
    mock_deps({ name = "tokyonight" }, function()
      loaded = true
      return { ok = true }
    end, function(cb)
      deferred = cb
    end)
    setup({ auto_load = true })
    assert.is_false(loaded)
    deferred()
    assert.is_true(loaded)
  end)

  it("registers only the root ThemeBrowser command", function()
    mock_deps(nil, function()
      return { ok = true }
    end)
    setup()
    assert.equals(2, vim.fn.exists(":ThemeBrowser"))
    assert.equals(0, vim.fn.exists(":ThemeBrowserUse"))
    assert.equals(0, vim.fn.exists(":ThemeBrowserReset"))
  end)

  it("provides theme name completion", function()
    package.loaded["theme-browser.persistence.state"] =
      { initialize = function() end, get_current_theme = function() end }
    package.loaded["theme-browser.adapters.registry"] = {
      initialize = function() end,
      is_initialized = function()
        return true
      end,
      get_theme = function(n)
        return n == "tokyonight" and { name = n } or nil
      end,
      resolve = function() end,
      list_themes = function()
        return { { name = "tokyonight" } }
      end,
      list_entries = function()
        return { { name = "tokyonight", variant = "tokyonight-night" } }
      end,
    }
    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function()
        return { ok = true }
      end,
      has_package_manager = function() end,
    }
    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(cb)
        cb()
      end,
    }
    setup()
    local matches = vim.fn.getcompletion("ThemeBrowser use tok", "cmdline")
    assert.is_true(vim.tbl_contains(matches, "tokyonight"))

    local root_matches = vim.fn.getcompletion("ThemeBrowser r", "cmdline")
    assert.is_true(vim.tbl_contains(root_matches, "registry"))

    local pm_matches = vim.fn.getcompletion("ThemeBrowser pm e", "cmdline")
    assert.is_true(vim.tbl_contains(pm_matches, "enable"))
  end)
end)
