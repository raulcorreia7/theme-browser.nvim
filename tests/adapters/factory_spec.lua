local test_utils = require("tests.helpers.test_utils")

describe("theme-browser.adapters.factory", function()
  local factory_module = "theme-browser.adapters.factory"
  local modules = {
    factory_module,
    "fake.theme",
    "fake.setuptheme",
    "fake.loadtheme",
    "fake.loadtheme2",
    "fake.settheme",
    "mytheme",
  }
  local original_colorscheme = vim.cmd.colorscheme

  before_each(function()
    test_utils.reset_all(modules)
    vim.cmd.colorscheme = function(_) end
  end)

  after_each(function()
    test_utils.restore_all(modules)
    vim.cmd.colorscheme = original_colorscheme
  end)

  it("applies vim.g options for colorscheme strategy", function()
    local factory = require(factory_module)
    vim.g.test_theme_background = nil

    local entry = test_utils.make_theme_entry("everforest", {
      repo = "sainnhe/everforest",
      meta = {
        strategy = {
          type = "colorscheme",
          vim = {
            g = {
              test_theme_background = "hard",
            },
          },
        },
      },
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("hard", vim.g.test_theme_background)
  end)

  it("applies vim.o options from entry meta", function()
    local factory = require(factory_module)
    local original_background = vim.o.background

    local entry = test_utils.make_theme_entry("everforest", {
      variant = "light",
      repo = "sainnhe/everforest",
      meta = {
        strategy = {
          type = "colorscheme",
          vim = {
            o = {
              background = "light",
            },
          },
        },
      },
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("light", vim.o.background)

    vim.o.background = original_background
  end)

  it("uses load module methods before colorscheme fallback", function()
    local factory = require(factory_module)
    local called = { load = 0 }

    package.loaded["fake.theme"] = {
      load = function(_)
        called.load = called.load + 1
      end,
    }

    local entry = test_utils.make_theme_entry("fake", {
      variant = "night",
      colorscheme = "fake-night",
      meta = {
        strategy = {
          type = "load",
          module = "fake.theme",
        },
      },
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals(1, called.load)
  end)

  it("uses colorscheme strategy as default when no strategy specified", function()
    local factory = require(factory_module)
    local colorscheme_calls = {}

    vim.cmd.colorscheme = function(cs)
      table.insert(colorscheme_calls, cs)
    end

    local entry = test_utils.make_theme_entry("simple-theme", {
      repo = "owner/simple-theme",
    })
    entry.meta = nil

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("colorscheme", result.strategy)
    assert.equals(1, #colorscheme_calls)
    assert.equals("simple-theme", colorscheme_calls[1])
  end)

  it("uses colorscheme strategy when explicitly specified", function()
    local factory = require(factory_module)
    local colorscheme_calls = {}

    vim.cmd.colorscheme = function(cs)
      table.insert(colorscheme_calls, cs)
    end

    local entry = test_utils.make_theme_entry("explicit-simple", {
      repo = "owner/explicit-simple",
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("colorscheme", result.strategy)
    assert.equals(1, #colorscheme_calls)
    assert.equals("explicit-simple", colorscheme_calls[1])
  end)

  it("calls setup() then colorscheme for setup strategy", function()
    local factory = require(factory_module)
    local calls = { setup = 0 }
    local setup_opts = nil

    package.loaded["fake.setuptheme"] = {
      setup = function(opts)
        calls.setup = calls.setup + 1
        setup_opts = opts
      end,
    }

    local entry = test_utils.make_theme_entry("fake", {
      variant = "dark",
      colorscheme = "fake-dark",
      meta = {
        strategy = {
          type = "setup",
          module = "fake.setuptheme",
          opts = { transparent = true },
        },
      },
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("setup", result.strategy)
    assert.equals(1, calls.setup)
    assert.is_not_nil(setup_opts)
    assert.is_true(setup_opts.transparent)
  end)

  it("tries common variant keys for setup themes (astrotheme palette)", function()
    local factory = require(factory_module)
    vim.g._tb_palette = nil

    package.loaded["fake.astrotheme"] = {
      setup = function(opts)
        -- Simulate astrotheme: expects opts.palette, ignores unknown keys.
        vim.g._tb_palette = opts and opts.palette or nil
      end,
    }

    vim.cmd.colorscheme = function(cs)
      if cs == "astrolight" and vim.g._tb_palette == "astrolight" then
        return
      end
      error("palette not set")
    end

    local entry = test_utils.make_theme_entry("astrotheme", {
      variant = "astrolight",
      colorscheme = "astrolight",
      meta = {
        strategy = {
          type = "setup",
          module = "fake.astrotheme",
        },
      },
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("astrolight", vim.g._tb_palette)
  end)

  it("calls load() directly for load strategy", function()
    local factory = require(factory_module)
    local calls = { load = 0 }
    local load_args = nil

    package.loaded["fake.loadtheme"] = {
      load = function(...)
        calls.load = calls.load + 1
        load_args = { ... }
      end,
    }

    local entry = test_utils.make_theme_entry("fake", {
      variant = "load",
      colorscheme = "fake-load",
      meta = {
        strategy = {
          type = "load",
          module = "fake.loadtheme",
          args = { "arg1", "arg2" },
        },
      },
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("load", result.strategy)
    assert.equals(1, calls.load)
    assert.is_not_nil(load_args)
    assert.equals(2, #load_args)
    assert.equals("arg1", load_args[1])
    assert.equals("arg2", load_args[2])
  end)

  it("calls load() without args when args not provided for load strategy", function()
    local factory = require(factory_module)
    local calls = { load = 0 }

    package.loaded["fake.loadtheme2"] = {
      load = function()
        calls.load = calls.load + 1
      end,
    }

    local entry = test_utils.make_theme_entry("fake", {
      variant = "load2",
      colorscheme = "fake-load2",
      meta = {
        strategy = {
          type = "load",
          module = "fake.loadtheme2",
        },
      },
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("load", result.strategy)
    assert.equals(1, calls.load)
  end)

  it("calls set() as fallback when load() not available for load strategy", function()
    local factory = require(factory_module)
    local calls = { setup = 0, set = 0 }

    package.loaded["fake.settheme"] = {
      setup = function()
        calls.setup = calls.setup + 1
      end,
      set = function(variant)
        calls.set = calls.set + 1
        calls.set_variant = variant
      end,
    }

    local entry = test_utils.make_theme_entry("fake", {
      variant = "ocean",
      colorscheme = "fake-ocean",
      meta = {
        strategy = {
          type = "load",
          module = "fake.settheme",
        },
      },
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("load", result.strategy)
    assert.equals(1, calls.setup)
    assert.equals(1, calls.set)
    assert.equals("fake-ocean", calls.set_variant)
  end)

  it("tries variant-specific colorscheme names when applying colorscheme", function()
    local factory = require(factory_module)
    local colorscheme_calls = {}

    vim.cmd.colorscheme = function(cs)
      table.insert(colorscheme_calls, cs)
      if #colorscheme_calls == 1 then
        error("colorscheme not found: " .. cs)
      end
    end

    local entry = test_utils.make_theme_entry("mytheme", {
      variant = "dark",
      repo = "owner/mytheme",
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.is_true(#colorscheme_calls >= 1)
    assert.equals("mytheme", colorscheme_calls[1])
  end)

  it("reports errors when colorscheme fails to apply", function()
    local factory = require(factory_module)

    vim.cmd.colorscheme = function(_)
      error("colorscheme not available")
    end

    local entry = test_utils.make_theme_entry("missing-theme", {
      repo = "owner/missing-theme",
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_false(result.ok)
    assert.is_not_nil(result.errors)
    assert.is_not_nil(result.errors.colorscheme_error)
  end)

  it("uses entry name as module when module not specified in meta", function()
    local factory = require(factory_module)
    local calls = { setup = 0 }

    package.loaded["mytheme"] = {
      setup = function()
        calls.setup = calls.setup + 1
      end,
    }

    local entry = test_utils.make_theme_entry("mytheme", {
      variant = "main",
      colorscheme = "mytheme-main",
      meta = {
        strategy = {
          type = "setup",
        },
      },
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals(1, calls.setup)
  end)

  it("returns mode from entry", function()
    local factory = require(factory_module)
    local colorscheme_calls = {}

    vim.cmd.colorscheme = function(cs)
      table.insert(colorscheme_calls, cs)
    end

    local entry = test_utils.make_theme_entry("mytheme", {
      variant = "dark",
      mode = "dark",
      repo = "owner/mytheme",
    })

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("dark", result.mode)
  end)
end)
