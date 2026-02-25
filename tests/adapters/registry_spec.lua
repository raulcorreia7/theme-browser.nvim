describe("theme-browser.adapters.registry", function()
  local registry_module = "theme-browser.adapters.registry"

  local function reload_registry()
    package.loaded[registry_module] = nil
    return require(registry_module)
  end

  local function write_temp_registry(payload)
    local path = vim.fn.tempname() .. ".json"
    vim.fn.writefile({ vim.json.encode(payload) }, path)
    return path
  end

  it("expands default and variant entries", function()
    local registry = reload_registry()
    local path = write_temp_registry({
      {
        name = "tokyonight",
        repo = "folke/tokyonight.nvim",
        colorscheme = "tokyonight",
        variants = { "tokyonight-night", "tokyonight-storm" },
      },
    })

    registry.initialize(path)
    local entries = registry.list_entries()

    -- Base entry excluded when variants exist - only variants shown
    assert.equals(2, #entries)
    -- When no variant requested, returns first variant
    assert.is_not_nil(registry.resolve("tokyonight", nil))
    assert.equals("tokyonight-night", registry.resolve("tokyonight", nil).variant)
    assert.is_not_nil(registry.resolve("tokyonight", "tokyonight-night"))
    assert.is_not_nil(registry.resolve("tokyonight", "tokyonight-storm"))
  end)

  it("resolves shorthand variant to prefixed colorscheme entry", function()
    local registry = reload_registry()
    local path = write_temp_registry({
      {
        name = "tokyonight",
        repo = "folke/tokyonight.nvim",
        colorscheme = "tokyonight",
        variants = { "tokyonight-night" },
      },
    })

    registry.initialize(path)
    local entry = registry.resolve("tokyonight", "night")

    assert.is_not_nil(entry)
    assert.equals("tokyonight:tokyonight-night", entry.id)
  end)

  it("falls back to base entry with requested variant", function()
    local registry = reload_registry()
    local path = write_temp_registry({
      {
        name = "everforest",
        repo = "sainnhe/everforest",
        colorscheme = "everforest",
      },
    })

    registry.initialize(path)
    local entry = registry.resolve("everforest", "light")
    assert.is_not_nil(entry)
    assert.equals("everforest:light", entry.id)
    assert.equals("light", entry.variant)
    assert.equals("everforest", entry.colorscheme)
  end)

  it("resolves by colorscheme alias when theme name differs", function()
    local registry = reload_registry()
    local path = write_temp_registry({
      {
        name = "github-nvim-theme",
        repo = "projekt0n/github-nvim-theme",
        colorscheme = "github_dark",
        variants = { "github_light" },
      },
    })

    registry.initialize(path)

    local theme = registry.get_theme("github_dark")
    local entry = registry.get_entry("github_light")
    assert.is_not_nil(theme)
    assert.equals("github-nvim-theme", theme.name)
    assert.is_not_nil(entry)
    assert.equals("github-nvim-theme:github_light", entry.id)
  end)

  it("does not duplicate default row when variants include base colorscheme", function()
    local registry = reload_registry()
    local path = write_temp_registry({
      {
        name = "github-nvim-theme",
        repo = "projekt0n/github-nvim-theme",
        colorscheme = "github_dark",
        variants = { "github_dark", "github_light" },
      },
    })

    registry.initialize(path)
    local entries = registry.list_entries()
    assert.equals(2, #entries)
  end)
end)
