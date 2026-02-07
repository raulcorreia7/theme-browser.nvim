describe("theme-browser.config.options", function()
  local module_name = "theme-browser.config.options"
  local defaults_name = "theme-browser.config.defaults"
  local snapshots = {}

  local function snapshot(name)
    snapshots[name] = package.loaded[name]
  end

  local function restore(name)
    if snapshots[name] == nil then
      package.loaded[name] = nil
    else
      package.loaded[name] = snapshots[name]
    end
  end

  before_each(function()
    snapshots = {}
    snapshot(module_name)
    snapshot(defaults_name)
    package.loaded[module_name] = nil
  end)

  after_each(function()
    restore(module_name)
    restore(defaults_name)
  end)

  it("returns normalized defaults when config is missing", function()
    local options = require(module_name)
    local defaults = require(defaults_name)
    local validated = options.validate(nil)

    assert.equals(defaults.startup.write_spec, validated.startup.write_spec)
    assert.is_false(validated.startup.write_spec)
    assert.equals(defaults.package_manager.mode, validated.package_manager.mode)
  end)

  it("warns and keeps defaults for unknown/invalid nested values", function()
    local options = require(module_name)
    local notifications = {}
    local original_notify = vim.notify

    local function has_notification(message)
      for _, item in ipairs(notifications) do
        if item.msg == message then
          return true
        end
      end
      return false
    end

    vim.notify = function(msg, level, _)
      table.insert(notifications, { msg = msg, level = level })
    end

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
      keymaps = {
        select = "<Space>",
        install = {},
      },
      unknown_top = true,
    })

    vim.notify = original_notify

    assert.is_false(validated.startup.write_spec)
    assert.equals(7, validated.cache.cleanup_interval_days)
    assert.equals(0.6, validated.ui.window_width)
    assert.equals("plugin_only", validated.package_manager.mode)
    assert.equals("auto", validated.package_manager.provider)
    assert.same({ "<Space>" }, validated.keymaps.select)
    assert.same({ "i" }, validated.keymaps.install)
    assert.is_false(validated.ui.preview_on_move)
    assert.is_nil(validated.default_theme)
    assert.is_true(has_notification("Unknown config option: default_theme"))
    assert.is_false(has_notification("Unknown config option: show_preview"))
    assert.is_true(has_notification("Config option 'show_preview' is deprecated; use ui.preview_on_move"))
    assert.is_true(#notifications > 0)
  end)
end)
