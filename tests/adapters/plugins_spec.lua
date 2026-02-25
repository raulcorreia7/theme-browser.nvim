describe("theme-browser.adapters.plugins", function()
  local module_name = "theme-browser.adapters.plugins"

  before_each(function()
    package.loaded[module_name] = nil
  end)

  after_each(function()
    package.loaded[module_name] = nil
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
          vim = { o = {}, g = {} }
        }
      },
    })

    assert.equals("everforest", entry.colorscheme)
    assert.equals("light", entry.meta.strategy.vim.o.background)
    assert.equals("soft", entry.meta.strategy.vim.g.everforest_background)
  end)
end)
