describe("theme-browser.adapters.factory", function()
  local factory_module = "theme-browser.adapters.factory"

  local original_colorscheme = vim.cmd.colorscheme

  before_each(function()
    package.loaded[factory_module] = nil
    vim.cmd.colorscheme = function(_) end
  end)

  after_each(function()
    vim.cmd.colorscheme = original_colorscheme
    package.loaded[factory_module] = nil
    package.loaded["fake.theme"] = nil
    package.loaded["fake.setuptheme"] = nil
    package.loaded["fake.loadtheme"] = nil
    package.loaded["fake.loadtheme2"] = nil
    package.loaded["fake.settheme"] = nil
    package.loaded["mytheme"] = nil
  end)

  it("applies vim.g options for vimg_colorscheme", function()
    local factory = require(factory_module)
    vim.g.test_theme_background = nil

    local entry = {
      id = "everforest",
      name = "everforest",
      repo = "sainnhe/everforest",
      colorscheme = "everforest",
      meta = {
        strategy = "vimg_colorscheme",
        opts_g = {
          test_theme_background = "hard",
        },
      },
    }

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("hard", vim.g.test_theme_background)
  end)

  it("applies vim.o options from entry meta", function()
    local factory = require(factory_module)
    local original_background = vim.o.background

    local entry = {
      id = "everforest:light",
      name = "everforest",
      variant = "light",
      repo = "sainnhe/everforest",
      colorscheme = "everforest",
      meta = {
        strategy = "vimg_colorscheme",
        opts_o = {
          background = "light",
        },
      },
    }

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("light", vim.o.background)

    vim.o.background = original_background
  end)

  it("uses setup_load module methods before colorscheme fallback", function()
    local factory = require(factory_module)
    local called = { load = 0 }

    package.loaded["fake.theme"] = {
      load = function(_)
        called.load = called.load + 1
      end,
    }

    local entry = {
      id = "fake:night",
      name = "fake",
      variant = "night",
      repo = "owner/fake",
      colorscheme = "fake-night",
      meta = {
        strategy = "setup_load",
        module = "fake.theme",
      },
    }

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals(1, called.load)
  end)

  it("uses colorscheme_only strategy as default when no strategy specified", function()
    local factory = require(factory_module)
    local colorscheme_calls = {}

    vim.cmd.colorscheme = function(cs)
      table.insert(colorscheme_calls, cs)
    end

    local entry = {
      id = "simple-theme",
      name = "simple-theme",
      repo = "owner/simple-theme",
      colorscheme = "simple-theme",
    }

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("colorscheme_only", result.strategy)
    assert.equals(1, #colorscheme_calls)
    assert.equals("simple-theme", colorscheme_calls[1])
  end)

  it("uses colorscheme_only strategy when explicitly specified", function()
    local factory = require(factory_module)
    local colorscheme_calls = {}

    vim.cmd.colorscheme = function(cs)
      table.insert(colorscheme_calls, cs)
    end

    local entry = {
      id = "explicit-simple",
      name = "explicit-simple",
      repo = "owner/explicit-simple",
      colorscheme = "explicit-simple",
      meta = {
        strategy = "colorscheme_only",
      },
    }

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("colorscheme_only", result.strategy)
    assert.equals(1, #colorscheme_calls)
    assert.equals("explicit-simple", colorscheme_calls[1])
  end)

  it("calls setup() then colorscheme for setup_colorscheme strategy", function()
    local factory = require(factory_module)
    local calls = { setup = 0 }
    local setup_opts = nil

    package.loaded["fake.setuptheme"] = {
      setup = function(opts)
        calls.setup = calls.setup + 1
        setup_opts = opts
      end,
    }

    local entry = {
      id = "fake:dark",
      name = "fake",
      variant = "dark",
      repo = "owner/fake",
      colorscheme = "fake-dark",
      meta = {
        strategy = "setup_colorscheme",
        module = "fake.setuptheme",
        opts = { transparent = true },
      },
    }

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("setup_colorscheme", result.strategy)
    assert.equals(1, calls.setup)
    assert.is_not_nil(setup_opts)
    assert.is_true(setup_opts.transparent)
  end)

  it("calls load() directly for load strategy", function()
    local factory = require(factory_module)
    local calls = { load = 0 }
    local load_args = nil

    package.loaded["fake.loadtheme"] = {
      load = function(...)
        calls.load = calls.load + 1
        load_args = {...}
      end,
    }

    local entry = {
      id = "fake:load",
      name = "fake",
      variant = "load",
      repo = "owner/fake",
      colorscheme = "fake-load",
      meta = {
        strategy = "load",
        module = "fake.loadtheme",
        args = { "arg1", "arg2" },
      },
    }

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

    local entry = {
      id = "fake:load2",
      name = "fake",
      variant = "load2",
      repo = "owner/fake",
      colorscheme = "fake-load2",
      meta = {
        strategy = "load",
        module = "fake.loadtheme2",
      },
    }

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("load", result.strategy)
    assert.equals(1, calls.load)
  end)

  it("calls set() as fallback when load() not available for setup_load strategy", function()
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

    local entry = {
      id = "fake:set",
      name = "fake",
      variant = "ocean",
      repo = "owner/fake",
      colorscheme = "fake-ocean",
      meta = {
        strategy = "setup_load",
        module = "fake.settheme",
      },
    }

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals("setup_load", result.strategy)
    assert.equals(1, calls.setup)
    assert.equals(1, calls.set)
    assert.equals("fake-ocean", calls.set_variant)
  end)

  it("tries variant-specific colorscheme names when applying colorscheme", function()
    local factory = require(factory_module)
    local colorscheme_calls = {}

    vim.cmd.colorscheme = function(cs)
      table.insert(colorscheme_calls, cs)
      -- Fail on first call, succeed on second
      if #colorscheme_calls == 1 then
        error("colorscheme not found: " .. cs)
      end
    end

    local entry = {
      id = "mytheme:dark",
      name = "mytheme",
      variant = "dark",
      repo = "owner/mytheme",
      colorscheme = "mytheme",
      meta = {
        strategy = "colorscheme_only",
      },
    }

    local result = factory.get_adapter(entry).load(entry)
    -- Should try mytheme, then dark, then mytheme-dark, then mytheme again
    assert.is_true(result.ok)
    assert.is_true(#colorscheme_calls >= 1)
    assert.equals("mytheme", colorscheme_calls[1])
  end)

  it("reports errors when colorscheme fails to apply", function()
    local factory = require(factory_module)

    vim.cmd.colorscheme = function(_)
      error("colorscheme not available")
    end

    local entry = {
      id = "missing-theme",
      name = "missing-theme",
      repo = "owner/missing-theme",
      colorscheme = "missing-theme",
      meta = {
        strategy = "colorscheme_only",
      },
    }

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

    local entry = {
      id = "mytheme:main",
      name = "mytheme",
      variant = "main",
      repo = "owner/mytheme",
      colorscheme = "mytheme-main",
      meta = {
        strategy = "setup_colorscheme",
        -- module not specified, should use entry.name
      },
    }

    local result = factory.get_adapter(entry).load(entry)
    assert.is_true(result.ok)
    assert.equals(1, calls.setup)
  end)
end)
