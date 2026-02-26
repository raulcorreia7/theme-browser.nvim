local test_utils = require("tests.helpers.test_utils")

describe("theme-browser.package_manager.manager", function()
  local module_name = "theme-browser.package_manager.manager"
  local modules = {
    module_name,
    "theme-browser.persistence.state",
    "lazy",
    "lazy.core.config",
    "lazy.manage.reloader",
    "theme-browser.package_manager.providers.lazy",
    "theme-browser.package_manager.providers.noop",
  }

  before_each(function()
    test_utils.reset_all(modules)
  end)

  after_each(function()
    test_utils.restore_all(modules)
  end)

  it("treats auto/manual/installed_only semantics explicitly", function()
    package.loaded["lazy"] = { load = function() end }

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "auto" }
      end,
    }

    local manager = require(module_name)
    assert.is_true(manager.is_managed())
    assert.is_true(manager.can_delegate_load())
    assert.is_true(manager.can_manage_install())

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "manual" }
      end,
    }
    assert.is_true(manager.is_managed())
    assert.is_false(manager.can_delegate_load())
    assert.is_true(manager.can_manage_install())

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "installed_only" }
      end,
    }
    assert.is_false(manager.is_managed())
    assert.is_false(manager.can_delegate_load())
    assert.is_false(manager.can_manage_install())
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
        return { enabled = true, mode = "installed_only" }
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

  it("installs and loads plugin immediately in managed modes", function()
    local install_called = false
    local load_called = false

    package.loaded["lazy"] = {
      install = function(_)
        install_called = true
      end,
      load = function(_)
        load_called = true
      end,
    }

    package.loaded["lazy.core.config"] = {
      plugins = {
        ["folke/tokyonight.nvim"] = { name = "tokyonight" },
      },
    }

    package.loaded["lazy.manage.reloader"] = {
      check = function(_) end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "manual" }
      end,
    }

    local manager = require(module_name)
    local ok = manager.install_entry({ name = "tokyonight", repo = "folke/tokyonight.nvim" }, { load = true })

    assert.is_true(ok)
    assert.is_true(install_called)
    assert.is_true(load_called)
  end)

  it("can force install even in installed_only mode", function()
    local install_called = false

    package.loaded["lazy"] = {
      install = function(_)
        install_called = true
      end,
      load = function(_) end,
    }

    package.loaded["lazy.core.config"] = {
      plugins = {
        ["folke/tokyonight.nvim"] = { name = "tokyonight" },
      },
    }

    package.loaded["lazy.manage.reloader"] = {
      check = function(_) end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = false, mode = "installed_only" }
      end,
    }

    local manager = require(module_name)
    local ok = manager.install_entry({ name = "tokyonight", repo = "folke/tokyonight.nvim" }, {
      load = false,
      force = true,
    })

    assert.is_true(ok)
    assert.is_true(install_called)
  end)

  it("supports provider abstraction with noop provider", function()
    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "auto", provider = "noop" }
      end,
    }

    local manager = require(module_name)

    assert.equals("noop", manager.get_provider())
    assert.is_false(manager.is_available())
    assert.is_false(manager.can_delegate_load())
  end)
end)
