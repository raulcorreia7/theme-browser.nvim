describe("theme-browser.package_manager.manager", function()
  local module_name = "theme-browser.package_manager.manager"
  local previous_lazy
  local previous_lazy_provider
  local previous_noop_provider

  before_each(function()
    previous_lazy = package.loaded["lazy"]
    previous_lazy_provider = package.loaded["theme-browser.package_manager.providers.lazy"]
    previous_noop_provider = package.loaded["theme-browser.package_manager.providers.noop"]
    package.loaded[module_name] = nil
    package.loaded["theme-browser.persistence.state"] = nil
    package.loaded["lazy"] = nil
    package.loaded["lazy.core.config"] = nil
    package.loaded["lazy.manage.reloader"] = nil
    package.loaded["theme-browser.package_manager.providers.lazy"] = nil
    package.loaded["theme-browser.package_manager.providers.noop"] = nil
  end)

  after_each(function()
    package.loaded[module_name] = nil
    package.loaded["theme-browser.persistence.state"] = nil
    package.loaded["lazy"] = previous_lazy
    package.loaded["lazy.core.config"] = nil
    package.loaded["lazy.manage.reloader"] = nil
    package.loaded["theme-browser.package_manager.providers.lazy"] = previous_lazy_provider
    package.loaded["theme-browser.package_manager.providers.noop"] = previous_noop_provider
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
