local test_utils = require("tests.helpers.test_utils")

describe("theme-browser.adapters.plugins", function()
  local module_name = "theme-browser.adapters.plugins"
  local modules = { module_name }

  before_each(function()
    test_utils.reset_all(modules)
  end)

  after_each(function()
    test_utils.restore_all(modules)
  end)

  it("applies everforest variant options for light mode", function()
    local plugins = require(module_name)
    local entry = plugins.apply({
      name = "everforest",
      variant = "light-soft",
      colorscheme = "everforest",
      meta = {
        strategy = {
          type = "colorscheme",
          vim = { o = {}, g = {} },
        },
      },
    })

    assert.equals("everforest", entry.colorscheme)
    assert.equals("light", entry.meta.strategy.vim.o.background)
    assert.equals("soft", entry.meta.strategy.vim.g.everforest_background)
  end)
end)
