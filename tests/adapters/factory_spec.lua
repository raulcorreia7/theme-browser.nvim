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
end)
