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
      meta = { strategy = "vimg_colorscheme" },
    })

    assert.equals("everforest", entry.colorscheme)
    assert.equals("light", entry.meta.opts_o.background)
    assert.equals("soft", entry.meta.opts_g.everforest_background)
  end)
end)
