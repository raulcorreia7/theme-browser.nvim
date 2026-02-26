describe("Integration: theme lifecycle", function()
  local test_utils = require("tests.helpers.test_utils")
  local fixtures = require("tests.helpers.fixtures.registry")

  local modules = {
    "theme-browser",
    "theme-browser.persistence.state",
    "theme-browser.adapters.registry",
    "theme-browser.adapters.base",
    "theme-browser.adapters.factory",
    "theme-browser.application.theme_service",
    "theme-browser.preview.manager",
    "theme-browser.package_manager.manager",
  }

  local temp_rtp, registry_path

  local function create_color_scheme(name)
    local path = temp_rtp .. "/colors/" .. name .. ".vim"
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({ "hi clear", "let g:colors_name = '" .. name .. "'" }, path)
  end

  local function init_modules()
    local state = require("theme-browser.persistence.state")
    state.initialize({ package_manager = { enabled = false } })
    local registry = require("theme-browser.adapters.registry")
    registry.initialize(registry_path)
    package.loaded["theme-browser.package_manager.manager"] = {
      can_manage_install = function()
        return false
      end,
      when_ready = function(cb)
        cb()
      end,
    }
    return state, registry
  end

  before_each(function()
    temp_rtp = vim.fn.tempname()
    vim.fn.mkdir(temp_rtp .. "/colors", "p")
    vim.opt.runtimepath:prepend(temp_rtp)
    registry_path = test_utils.write_registry(fixtures.standard)
    for _, name in ipairs({ "tokyonight", "tokyonight-night", "catppuccin", "catppuccin-mocha" }) do
      create_color_scheme(name)
    end
    test_utils.reset_all(modules)
  end)

  after_each(function()
    if temp_rtp and vim.fn.isdirectory(temp_rtp) == 1 then
      pcall(function()
        vim.opt.runtimepath:remove(temp_rtp)
      end)
      vim.fn.delete(temp_rtp, "rf")
    end
    test_utils.restore_all(modules)
  end)

  it("loads theme by name", function()
    init_modules()
    local result = require("theme-browser.adapters.base").load_theme("tokyonight", nil, { notify = false })
    assert.is_true(result.ok)
    assert.equals("tokyonight", result.name)
  end)

  it("loads theme variant", function()
    init_modules()
    local result =
      require("theme-browser.adapters.base").load_theme("tokyonight", "tokyonight-night", { notify = false })
    assert.is_true(result.ok)
    assert.equals("tokyonight-night", result.variant)
  end)

  it("preview does not persist state", function()
    local state = init_modules()
    state.set_current_theme("catppuccin", "catppuccin-mocha")
    require("theme-browser.preview.manager").create_preview("tokyonight", "tokyonight-night")
    assert.equals("catppuccin", state.get_current_theme().name)
  end)

  it("apply persists state", function()
    local state = init_modules()
    require("theme-browser.adapters.base").load_theme("tokyonight", "tokyonight-night", { notify = false })
    vim.wait(100)
    local current = state.get_current_theme()
    assert.is_not_nil(current)
    assert.equals("tokyonight", current.name)
  end)

  it("returns error for missing theme", function()
    init_modules()
    local result = require("theme-browser.adapters.base").load_theme("nonexistent", nil, { notify = false })
    assert.is_false(result.ok)
    assert.is_not_nil(result.errors)
  end)

  it("use applies theme via service", function()
    local state = init_modules()
    local result = require("theme-browser.application.theme_service").use(
      "tokyonight",
      "tokyonight-night",
      { notify = false }
    )
    assert.is_true(result.ok)
    assert.equals("tokyonight", state.get_current_theme().name)
  end)

  it("preview applies temporarily via service", function()
    local state = init_modules()
    state.set_current_theme("catppuccin", "catppuccin-mocha")
    local code = require("theme-browser.application.theme_service").preview(
      "tokyonight",
      "tokyonight-night",
      { notify = false }
    )
    assert.equals(0, code)
    assert.equals("catppuccin", state.get_current_theme().name)
  end)
end)
