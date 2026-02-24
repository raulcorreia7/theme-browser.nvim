describe("theme-browser.startup.restore", function()
  local module_name = "theme-browser.startup.restore"
  local snapshots = {}

  local function snapshot(name)
    snapshots[name] = package.loaded[name]
  end

  local function restore(name)
    local previous = snapshots[name]
    if previous == nil then
      package.loaded[name] = nil
    else
      package.loaded[name] = previous
    end
  end

  before_each(function()
    snapshots = {}
    snapshot(module_name)
    snapshot("theme-browser.startup.config")
    snapshot("theme-browser.adapters.base")
    package.loaded[module_name] = nil
    package.loaded["theme-browser.startup.config"] = nil
    package.loaded["theme-browser.adapters.base"] = nil
  end)

  after_each(function()
    restore(module_name)
    restore("theme-browser.startup.config")
    restore("theme-browser.adapters.base")
  end)

  it("skips restore when target colorscheme is already active", function()
    local original_colors_name = vim.g.colors_name
    vim.g.colors_name = "tokyonight-night"

    local restore_startup = require(module_name)
    local should_skip = restore_startup.should_skip(
      { startup = { skip_if_already_active = true } },
      {
        get_startup_theme = function()
          return { colorscheme = "tokyonight-night" }
        end,
      },
      {
        name = "tokyonight",
        colorscheme = "tokyonight-night",
      }
    )

    vim.g.colors_name = original_colors_name
    assert.is_true(should_skip)
  end)

  it("does not skip restore when skip_if_already_active is disabled", function()
    local original_colors_name = vim.g.colors_name
    vim.g.colors_name = "tokyonight-night"

    local restore_startup = require(module_name)
    local should_skip = restore_startup.should_skip(
      { startup = { skip_if_already_active = false } },
      {
        get_startup_theme = function()
          return { colorscheme = "tokyonight-night" }
        end,
      },
      {
        name = "tokyonight",
        colorscheme = "tokyonight-night",
      }
    )

    vim.g.colors_name = original_colors_name
    assert.is_false(should_skip)
  end)

  it("restores current theme through base loader when not skipped", function()
    local called = nil
    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(name, variant, opts)
        called = { name = name, variant = variant, opts = opts }
        return { ok = true }
      end,
    }

    local restore_startup = require(module_name)
    local restored = restore_startup.restore_current_theme(
      { startup = { skip_if_already_active = true } },
      {
        get_current_theme = function()
          return { name = "tokyonight", variant = "tokyonight-night" }
        end,
        get_startup_theme = function()
          return { colorscheme = "tokyonight" }
        end,
      },
      {
        resolve = function(_, _)
          return {
            name = "tokyonight",
            variant = "tokyonight-night",
            colorscheme = "tokyonight-night",
          }
        end,
      }
    )

    assert.is_true(restored)
    assert.is_not_nil(called)
    assert.equals("tokyonight", called.name)
    assert.equals("tokyonight-night", called.variant)
    assert.is_false(called.opts.notify)
    assert.is_false(called.opts.persist_startup)
  end)

  it("returns false when base loader does not apply theme", function()
    local called = nil
    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(name, variant, opts)
        called = { name = name, variant = variant, opts = opts }
        return { ok = false }
      end,
    }

    local restore_startup = require(module_name)
    local restored = restore_startup.restore_current_theme(
      { startup = { skip_if_already_active = true } },
      {
        get_current_theme = function()
          return { name = "tokyonight", variant = "tokyonight-night" }
        end,
        get_startup_theme = function()
          return { colorscheme = "tokyonight" }
        end,
      },
      {
        resolve = function(_, _)
          return {
            name = "tokyonight",
            variant = "tokyonight-night",
            colorscheme = "tokyonight-night",
          }
        end,
      }
    )

    assert.is_false(restored)
    assert.is_not_nil(called)
    assert.equals("tokyonight", called.name)
    assert.equals("tokyonight-night", called.variant)
  end)

  it("does not restore when active colorscheme already matches target", function()
    local original_colors_name = vim.g.colors_name
    vim.g.colors_name = "tokyonight-night"

    local called = false
    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        called = true
      end,
    }

    local restore_startup = require(module_name)
    local restored = restore_startup.restore_current_theme(
      { startup = { skip_if_already_active = true } },
      {
        get_current_theme = function()
          return { name = "tokyonight", variant = "tokyonight-night" }
        end,
        get_startup_theme = function()
          return { colorscheme = "tokyonight-night" }
        end,
      },
      {
        resolve = function(_, _)
          return {
            name = "tokyonight",
            variant = "tokyonight-night",
            colorscheme = "tokyonight-night",
          }
        end,
      }
    )

    vim.g.colors_name = original_colors_name
    assert.is_false(restored)
    assert.is_false(called)
  end)
end)
