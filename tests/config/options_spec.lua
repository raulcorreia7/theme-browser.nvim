local test_utils = require("tests.helpers.test_utils")

describe("theme-browser.config.options", function()
  local module_name = "theme-browser.config.options"
  local defaults_name = "theme-browser.config.defaults"
  local modules = { module_name, defaults_name }

  before_each(function()
    test_utils.reset_all(modules)
  end)

  after_each(function()
    test_utils.restore_all(modules)
  end)

  it("returns normalized defaults when config is missing", function()
    local options = require(module_name)
    local defaults = require(defaults_name)
    local validated = options.validate(nil)

    assert.equals(defaults.startup.write_spec, validated.startup.write_spec)
    assert.is_true(validated.startup.write_spec)
    assert.equals(defaults.package_manager.mode, validated.package_manager.mode)
    assert.equals("stable", validated.registry.channel)
  end)

  it("warns and keeps defaults for unknown/invalid nested values", function()
    local notify_mock = test_utils.mock_vim_notify()
    local options = require(module_name)

    local validated = options.validate({
      default_theme = "tokyonight",
      show_preview = false,
      startup = {
        write_spec = "yes",
        unknown = true,
      },
      cache = {
        cleanup_interval_days = -2,
      },
      ui = {
        window_width = 5,
      },
      package_manager = {
        mode = "invalid",
        provider = "invalid",
      },
      registry = {
        channel = "beta",
      },
      keymaps = {
        select = "<Space>",
        install = {},
      },
      unknown_top = true,
    })

    notify_mock.restore()

    assert.is_true(validated.startup.write_spec)
    assert.equals(7, validated.cache.cleanup_interval_days)
    assert.equals(0.6, validated.ui.window_width)
    assert.equals("manual", validated.package_manager.mode)
    assert.equals("auto", validated.package_manager.provider)
    assert.equals("stable", validated.registry.channel)
    assert.same({ "<Space>" }, validated.keymaps.select)
    assert.same({ "i" }, validated.keymaps.install)
    assert.is_true(validated.ui.preview_on_move)
    assert.is_nil(validated.default_theme)
    assert.is_true(notify_mock.has_warning("Unknown config option: default_theme"))
    assert.is_true(notify_mock.has_warning("Unknown config option: show_preview"))
    assert.is_true(#notify_mock.calls > 0)
  end)

  it("accepts registry latest channel", function()
    local options = require(module_name)
    local validated = options.validate({
      registry = { channel = "latest" },
    })

    assert.equals("latest", validated.registry.channel)
  end)

  it("normalizes local repo source inputs as arrays", function()
    local options = require(module_name)
    local validated = options.validate({
      local_repo_sources = {
        " /home/user/projects ",
        "/home/user/themes;/home/user/projects",
      },
    })

    assert.same({ "/home/user/projects", "/home/user/themes" }, validated.local_repo_sources)
  end)

  it("accepts scroll keymap overrides", function()
    local options = require(module_name)
    local validated = options.validate({
      keymaps = {
        scroll_up = "<C-b>",
        scroll_down = { "<C-f>" },
      },
    })

    assert.same({ "<C-b>" }, validated.keymaps.scroll_up)
    assert.same({ "<C-f>" }, validated.keymaps.scroll_down)
  end)
end)
