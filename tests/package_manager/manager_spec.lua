describe("theme-browser.package_manager.manager", function()
  local module_name = "theme-browser.package_manager.manager"
  local previous_lazy

  before_each(function()
    previous_lazy = package.loaded["lazy"]
    package.loaded[module_name] = nil
    package.loaded["theme-browser.persistence.state"] = nil
    package.loaded["lazy"] = nil
  end)

  after_each(function()
    package.loaded[module_name] = nil
    package.loaded["theme-browser.persistence.state"] = nil
    package.loaded["lazy"] = previous_lazy
  end)

  it("treats auto/manual/plugin_only semantics explicitly", function()
    package.loaded["lazy"] = { load = function() end }

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "auto" }
      end,
    }

    local manager = require(module_name)
    assert.is_true(manager.is_managed())
    assert.is_true(manager.can_delegate_load())

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "manual" }
      end,
    }
    assert.is_true(manager.is_managed())
    assert.is_false(manager.can_delegate_load())

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "plugin_only" }
      end,
    }
    assert.is_false(manager.is_managed())
    assert.is_false(manager.can_delegate_load())
  end)

  it("loads lazy entry only in auto mode", function()
    local called = false
    package.loaded["lazy"] = {
      load = function(_)
        called = true
      end,
    }

    local manager = require(module_name)

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "plugin_only" }
      end,
    }
    assert.is_false(manager.load_entry({ name = "tokyonight", repo = "folke/tokyonight.nvim" }))
    assert.is_false(called)

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "manual" }
      end,
    }
    assert.is_false(manager.load_entry({ name = "tokyonight", repo = "folke/tokyonight.nvim" }))
    assert.is_false(called)

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "auto" }
      end,
    }
    assert.is_true(manager.load_entry({ name = "tokyonight", repo = "folke/tokyonight.nvim" }))

    assert.is_true(called)
  end)
end)
