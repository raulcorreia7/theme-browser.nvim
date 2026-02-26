local test_utils = require("tests.helpers.test_utils")

describe("theme-browser.adapters.base", function()
  local module_name = "theme-browser.adapters.base"
  local modules = {
    module_name,
    "theme-browser.adapters.factory",
    "theme-browser.adapters.registry",
    "theme-browser.runtime.loader",
    "theme-browser.persistence.state",
    "theme-browser.package_manager.manager",
    "theme-browser.startup.persistence",
  }

  before_each(function()
    test_utils.reset_all(modules)
  end)

  after_each(function()
    test_utils.restore_all(modules)
  end)

  it("fails fast when theme assets are missing", function()
    local calls = { factory = 0, set_current = 0, attach_cached_runtime = 0 }

    package.loaded["theme-browser.adapters.factory"] = {
      load_theme = function(_, _, _)
        calls.factory = calls.factory + 1
        return { ok = false, errors = { colorscheme_error = "not found" } }
      end,
      get_theme_status = function()
        return { installed = false }
      end,
    }

    package.loaded["theme-browser.runtime.loader"] = {
      attach_cached_runtime = function(_, _)
        calls.attach_cached_runtime = calls.attach_cached_runtime + 1
        return false, "theme is not cached", nil
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      set_current_theme = function(_, _)
        calls.set_current = calls.set_current + 1
      end,
      get_package_manager = function()
        return { enabled = false, mode = "installed_only" }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      is_available = function()
        return false
      end,
      is_managed = function()
        return false
      end,
    }

    local base = require(module_name)
    local result = base.load_theme("tokyonight", "night", { notify = false })

    assert.is_false(result.ok)
    assert.equals(1, calls.attach_cached_runtime)
    assert.equals(1, calls.factory)
    assert.equals(0, calls.set_current)
  end)

  it("persists current theme after successful apply", function()
    local calls = {
      factory = 0,
      set_current = 0,
      startup_persist = 0,
      attach_cached_runtime = 0,
    }
    local persisted = {}

    package.loaded["theme-browser.adapters.factory"] = {
      load_theme = function(_, _, _)
        calls.factory = calls.factory + 1
        return {
          ok = true,
          name = "tokyonight",
          variant = "night",
          colorscheme = "tokyonight-night",
        }
      end,
      get_theme_status = function()
        return { installed = true }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(name, variant)
        return { name = name, variant = variant }
      end,
    }

    package.loaded["theme-browser.runtime.loader"] = {
      attach_cached_runtime = function(_, _)
        calls.attach_cached_runtime = calls.attach_cached_runtime + 1
        return true, nil, "/tmp/tokyonight"
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      set_current_theme = function(name, variant)
        calls.set_current = calls.set_current + 1
        persisted[#persisted + 1] = { name = name, variant = variant }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      is_available = function()
        return true
      end,
      is_managed = function()
        return true
      end,
    }

    package.loaded["theme-browser.startup.persistence"] = {
      persist_applied_theme = function(_, _, _, _)
        calls.startup_persist = calls.startup_persist + 1
      end,
    }

    local base = require(module_name)
    local result = base.load_theme("tokyonight", "night", { notify = false })

    assert.is_true(result.ok)
    assert.equals(1, calls.factory)
    assert.equals(1, calls.attach_cached_runtime)
    assert.equals(1, calls.set_current)
    assert.equals(1, calls.startup_persist)
    assert.same({ { name = "tokyonight", variant = "night" } }, persisted)
  end)
end)
