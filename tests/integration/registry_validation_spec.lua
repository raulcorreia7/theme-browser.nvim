describe("Integration: registry validation", function()
  local test_utils = require("tests.helpers.test_utils")
  local modules = { "theme-browser", "theme-browser.adapters.registry" }
  local registry_path, registry

  local function setup_registry()
    local tb = require("theme-browser")
    tb.setup({
      registry_path = registry_path,
      auto_load = false,
      startup = { enabled = false },
    })
    registry = require("theme-browser.adapters.registry")
  end

  before_each(function()
    test_utils.reset_all(modules)
    registry_path = test_utils.get_bundled_registry_path()
  end)

  after_each(function()
    test_utils.restore_all(modules)
  end)

  it("loads bundled registry successfully", function()
    assert.is_not_nil(registry_path, "Bundled registry not found")
    setup_registry()
    assert.is_true(registry.is_initialized())
  end)

  it("has tokyonight with 4 variants", function()
    setup_registry()
    local theme = registry.get_theme("tokyonight")
    assert.is_not_nil(theme)
    assert.equals("folke/tokyonight.nvim", theme.repo)
    assert.equals(4, #theme.variants)
  end)

  it("has catppuccin with 4 variants", function()
    setup_registry()
    local theme = registry.get_theme("catppuccin")
    assert.is_not_nil(theme)
    assert.equals("catppuccin/nvim", theme.repo)
    assert.equals(4, #theme.variants)
  end)

  it("has iceberg and nordic themes", function()
    setup_registry()
    assert.is_not_nil(registry.get_theme("iceberg"))
    assert.is_not_nil(registry.get_theme("nordic"))
  end)

  it("tokyonight has expected variant names", function()
    setup_registry()
    local theme = registry.get_theme("tokyonight")
    local names = {}
    for _, v in ipairs(theme.variants) do
      names[v.name] = true
    end
    assert.is_true(names["tokyonight-night"])
    assert.is_true(names["tokyonight-storm"])
    assert.is_true(names["tokyonight-moon"])
    assert.is_true(names["tokyonight-day"])
  end)

  it("resolves by name and variant", function()
    setup_registry()
    local entry = registry.resolve("tokyonight", "tokyonight-night")
    assert.is_not_nil(entry)
    assert.equals("tokyonight", entry.name)
    assert.equals("tokyonight-night", entry.variant)
  end)

  it("resolves by entry id", function()
    setup_registry()
    local entry = registry.get_entry("tokyonight:tokyonight-night")
    assert.is_not_nil(entry)
    assert.equals("tokyonight-night", entry.variant)
  end)

  it("lists all entries", function()
    setup_registry()
    assert.is_true(#registry.list_entries() >= 40)
  end)
end)
