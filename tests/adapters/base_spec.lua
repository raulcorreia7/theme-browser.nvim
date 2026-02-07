describe("theme-browser.adapters.base", function()
  local module_name = "theme-browser.adapters.base"
  local snapshots = {}

  local function snapshot(name)
    snapshots[name] = package.loaded[name]
  end

  local function restore(name)
    local prev = snapshots[name]
    if prev == nil then
      package.loaded[name] = nil
    else
      package.loaded[name] = prev
    end
  end

  before_each(function()
    snapshots = {}
    snapshot(module_name)
    snapshot("theme-browser.adapters.factory")
    snapshot("theme-browser.adapters.registry")
    snapshot("theme-browser.runtime.loader")
    snapshot("theme-browser.persistence.state")
    snapshot("theme-browser.package_manager.manager")
    snapshot("theme-browser.startup.persistence")

    package.loaded[module_name] = nil
  end)

  after_each(function()
    restore(module_name)
    restore("theme-browser.adapters.factory")
    restore("theme-browser.adapters.registry")
    restore("theme-browser.runtime.loader")
    restore("theme-browser.persistence.state")
    restore("theme-browser.package_manager.manager")
    restore("theme-browser.startup.persistence")
  end)

  it("retries in background when theme assets are missing", function()
    local calls = { factory = 0, set_current = 0, ensure = 0 }

    package.loaded["theme-browser.adapters.factory"] = {
      load_theme = function(_, _, _)
        calls.factory = calls.factory + 1
        if calls.factory == 1 then
          return { ok = false, errors = { colorscheme_error = "not found" } }
        end
        return { ok = true, name = "tokyonight", variant = "night", colorscheme = "tokyonight-night" }
      end,
      get_theme_status = function()
        return { installed = false }
      end,
    }

    package.loaded["theme-browser.runtime.loader"] = {
      ensure_available = function(_, _, _, cb)
        calls.ensure = calls.ensure + 1
        cb(true, nil)
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      set_current_theme = function(_, _)
        calls.set_current = calls.set_current + 1
      end,
      get_package_manager = function()
        return { enabled = false, mode = "plugin_only" }
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
    assert.is_true(result.pending)
    assert.equals(1, calls.ensure)
    assert.equals(2, calls.factory)
    assert.equals(1, calls.set_current)
  end)

  it("persists current theme in managed mode only after successful apply", function()
    local calls = {
      factory = 0,
      package_load = 0,
      set_current = 0,
      startup_persist = 0,
      runtime_ensure = 0,
    }
    local persisted = {}

    package.loaded["theme-browser.adapters.factory"] = {
      load_theme = function(_, _, _)
        calls.factory = calls.factory + 1
        if calls.factory == 1 then
          return { ok = false, errors = { colorscheme_error = "not found" } }
        end
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
      ensure_available = function(_, _, _, _)
        calls.runtime_ensure = calls.runtime_ensure + 1
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
      load_theme = function(_, _)
        calls.package_load = calls.package_load + 1
        assert.equals(0, calls.set_current)
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
    assert.equals(2, calls.factory)
    assert.equals(1, calls.package_load)
    assert.equals(0, calls.runtime_ensure)
    assert.equals(1, calls.set_current)
    assert.equals(1, calls.startup_persist)
    assert.same({ { name = "tokyonight", variant = "night" } }, persisted)
  end)
end)
