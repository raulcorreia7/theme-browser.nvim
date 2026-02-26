describe("theme-browser.application.theme_service", function()
  local module_name = "theme-browser.application.theme_service"
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
    snapshot("theme-browser.adapters.base")
    snapshot("theme-browser.package_manager.manager")
    snapshot("theme-browser.preview.manager")
    snapshot("theme-browser.adapters.registry")
    snapshot("theme-browser.runtime.loader")

    package.loaded[module_name] = nil
  end)

  after_each(function()
    restore(module_name)
    restore("theme-browser.adapters.base")
    restore("theme-browser.package_manager.manager")
    restore("theme-browser.preview.manager")
    restore("theme-browser.adapters.registry")
    restore("theme-browser.runtime.loader")
  end)

  it("uses already available theme without package manager install", function()
    local calls = { load_theme = 0, install_theme = 0 }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(name, variant, _)
        calls.load_theme = calls.load_theme + 1
        return {
          ok = true,
          name = name,
          variant = variant,
          colorscheme = "tokyonight-night",
        }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      can_manage_install = function()
        return true
      end,
      install_theme = function()
        calls.install_theme = calls.install_theme + 1
        return true
      end,
    }

    local service = require(module_name)
    local result = service.use("tokyonight", "tokyonight-night", { notify = false })

    assert.is_true(result.ok)
    assert.equals(1, calls.load_theme)
    assert.equals(0, calls.install_theme)
  end)

  it("installs missing theme then retries apply via callback", function()
    local calls = { load_theme = 0, install_theme = 0 }
    local callback_result = nil
    local callback_called = false

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(name, variant, _)
        calls.load_theme = calls.load_theme + 1
        if calls.load_theme == 1 then
          return {
            ok = false,
            errors = { runtime_error = "theme is not cached or installed" },
          }
        end

        return {
          ok = true,
          name = name,
          variant = variant,
          colorscheme = "tokyonight-night",
        }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      can_manage_install = function()
        return true
      end,
      is_ready = function()
        return true
      end,
      install_theme = function(_, _, _)
        calls.install_theme = calls.install_theme + 1
        return true
      end,
    }

    package.loaded["theme-browser.runtime.loader"] = {
      attach_cached_runtime = function()
        return true, nil
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function()
        return { repo = "folke/tokyonight.nvim" }
      end,
    }

    local service = require(module_name)
    local result = service.use(
      "tokyonight",
      "tokyonight-night",
      { notify = false },
      function(success, res, err)
        callback_called = true
        callback_result = { success = success, res = res, err = err }
      end
    )

    assert.is_true(result.ok or result.async_pending)

    for _ = 1, 50 do
      vim.wait(100)
      if callback_called then
        break
      end
    end

    assert.is_true(callback_called)
    assert.is_true(callback_result.success)
  end)

  it("returns initial failure when install is unavailable", function()
    local calls = { load_theme = 0 }
    local callback_result = nil
    local callback_called = false

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        calls.load_theme = calls.load_theme + 1
        return {
          ok = false,
          errors = { runtime_error = "theme is not cached or installed" },
        }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      can_manage_install = function()
        return false
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function()
        return nil
      end,
    }

    local service = require(module_name)
    local result = service.use(
      "tokyonight",
      "tokyonight-night",
      { notify = false },
      function(success, res, err)
        callback_called = true
        callback_result = { success = success, res = res, err = err }
      end
    )

    assert.is_true(result.async_pending)

    local waited = vim.wait(2000, function()
      return callback_called
    end)

    assert.is_true(waited)
    assert.is_true(callback_called)
    assert.is_false(callback_result.success)
    assert.is_true(calls.load_theme >= 1)
  end)

  it("keeps install as alias to use", function()
    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        return { ok = true, name = "tokyonight", colorscheme = "tokyonight-night" }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      can_manage_install = function()
        return true
      end,
      install_theme = function(_, _, _)
        return true
      end,
    }

    local service = require(module_name)
    local result = service.install("tokyonight", "tokyonight-night", { notify = false })
    assert.is_true(result.ok)
  end)

  describe("preview function", function()
    it("returns 0 on successful preview", function()
      package.loaded["theme-browser.adapters.base"] = {
        load_theme = function(_, _, _)
          return { ok = true, name = "tokyonight", colorscheme = "tokyonight-night" }
        end,
      }

      local service = require(module_name)
      local status = service.preview("tokyonight", "tokyonight-night", { notify = false })

      assert.equals(0, status)
    end)

    it("returns 0 and triggers async install for missing theme", function()
      local calls = { load_theme = 0 }

      package.loaded["theme-browser.adapters.base"] = {
        load_theme = function(_, _, opts)
          calls.load_theme = calls.load_theme + 1
          if calls.load_theme == 1 then
            return { ok = false, errors = { runtime_error = "not found" } }
          end
          return { ok = true, name = "tokyonight", colorscheme = "tokyonight-night" }
        end,
      }

      package.loaded["theme-browser.package_manager.manager"] = {
        can_manage_install = function()
          return true
        end,
        install_theme = function()
          return true
        end,
      }

      package.loaded["theme-browser.runtime.loader"] = {
        attach_cached_runtime = function()
          return true, nil
        end,
      }

      package.loaded["theme-browser.adapters.registry"] = {
        resolve = function()
          return { repo = "folke/tokyonight.nvim" }
        end,
      }

      local service = require(module_name)
      local status = service.preview("tokyonight", "tokyonight-night", { notify = false })

      assert.equals(0, status)
    end)

    it("returns 0 even when install unavailable (triggers github fallback)", function()
      package.loaded["theme-browser.adapters.base"] = {
        load_theme = function(_, _, _)
          return { ok = false, errors = { runtime_error = "not found" } }
        end,
      }

      package.loaded["theme-browser.package_manager.manager"] = {
        can_manage_install = function()
          return false
        end,
      }

      package.loaded["theme-browser.adapters.registry"] = {
        resolve = function()
          return { repo = "owner/repo" }
        end,
      }

      local service = require(module_name)
      local status = service.preview("tokyonight", "tokyonight-night", { notify = false })

      assert.equals(0, status)
    end)
  end)

  describe("conflict detection", function()
    it("warns when theme has conflicts in meta", function()
      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        if level == vim.log.levels.WARN then
          table.insert(warnings, msg)
        end
      end

      finally(function()
        vim.notify = original_notify
      end)

      package.loaded["theme-browser.adapters.base"] = {
        load_theme = function()
          return { ok = false, errors = { runtime_error = "not found" } }
        end,
      }

      package.loaded["theme-browser.package_manager.manager"] = {
        can_manage_install = function()
          return false
        end,
      }

      package.loaded["theme-browser.adapters.registry"] = {
        resolve = function()
          return {
            name = "habamax",
            repo = "ntk148v/habamax.nvim",
            meta = {
              source = "github",
              conflicts = { "habamax" },
            },
          }
        end,
      }

      local service = require(module_name)
      service.use("habamax", nil, { notify = true }, function() end)

      vim.wait(100)

      local found_conflict_warning = false
      for _, msg in ipairs(warnings) do
        if msg:match("conflict") and msg:match("habamax") then
          found_conflict_warning = true
          break
        end
      end
      assert.is_true(found_conflict_warning)
    end)

    it("does not warn when theme has no conflicts", function()
      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        if level == vim.log.levels.WARN then
          table.insert(warnings, msg)
        end
      end

      finally(function()
        vim.notify = original_notify
      end)

      package.loaded["theme-browser.adapters.base"] = {
        load_theme = function()
          return { ok = true, name = "tokyonight", colorscheme = "tokyonight" }
        end,
      }

      package.loaded["theme-browser.package_manager.manager"] = {
        can_manage_install = function()
          return true
        end,
      }

      package.loaded["theme-browser.adapters.registry"] = {
        resolve = function()
          return {
            name = "tokyonight",
            repo = "folke/tokyonight.nvim",
            meta = { source = "github" },
          }
        end,
      }

      local service = require(module_name)
      service.use("tokyonight", nil, { notify = true })

      vim.wait(50)

      local found_conflict_warning = false
      for _, msg in ipairs(warnings) do
        if msg:match("conflict") then
          found_conflict_warning = true
          break
        end
      end
      assert.is_false(found_conflict_warning)
    end)

    it("handles multiple conflict names", function()
      local warnings = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        if level == vim.log.levels.WARN then
          table.insert(warnings, msg)
        end
      end

      finally(function()
        vim.notify = original_notify
      end)

      package.loaded["theme-browser.adapters.base"] = {
        load_theme = function()
          return { ok = false, errors = { runtime_error = "not found" } }
        end,
      }

      package.loaded["theme-browser.package_manager.manager"] = {
        can_manage_install = function()
          return false
        end,
      }

      package.loaded["theme-browser.adapters.registry"] = {
        resolve = function()
          return {
            name = "test",
            repo = "owner/test.nvim",
            meta = {
              source = "github",
              conflicts = { "blue", "darkblue" },
            },
          }
        end,
      }

      local service = require(module_name)
      service.use("test", nil, { notify = true }, function() end)

      vim.wait(100)

      local found_multi_conflict = false
      for _, msg in ipairs(warnings) do
        if msg:match("conflict") and msg:match("blue") and msg:match("darkblue") then
          found_multi_conflict = true
          break
        end
      end
      assert.is_true(found_multi_conflict)
    end)
  end)
end)
