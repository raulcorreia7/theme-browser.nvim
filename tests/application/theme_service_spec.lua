describe("theme-browser.application.theme_service", function()
  local module_name = "theme-browser.application.theme_service"
  local test_utils = require("tests.helpers.test_utils")
  local service

  local function setup_mocks(opts)
    opts = opts or {}
    local load_calls = 0

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(name, variant, _)
        load_calls = load_calls + 1
        if opts.fail_always then
          return { ok = false, errors = { runtime_error = opts.fail_error or "not found" } }
        end
        if load_calls == 1 and opts.fail_first then
          return { ok = false, errors = { runtime_error = opts.fail_error or "not found" } }
        end
        return {
          ok = opts.load_success ~= false,
          name = name,
          variant = variant,
          colorscheme = opts.colorscheme or (variant or name),
        }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      can_manage_install = function()
        return opts.can_manage ~= false
      end,
      is_ready = function()
        return opts.is_ready ~= false
      end,
      install_theme = function()
        return opts.install_success ~= false
      end,
    }

    package.loaded["theme-browser.runtime.loader"] = {
      attach_cached_runtime = function()
        return opts.attach_success ~= false, nil
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function()
        if opts.no_resolve then
          return nil
        end
        return {
          name = opts.name or "tokyonight",
          repo = opts.repo or "folke/tokyonight.nvim",
          meta = opts.meta,
        }
      end,
    }

    return function()
      return load_calls
    end
  end

  before_each(function()
    test_utils.reset_all({
      module_name,
      "theme-browser.adapters.base",
      "theme-browser.package_manager.manager",
      "theme-browser.preview.manager",
      "theme-browser.adapters.registry",
      "theme-browser.runtime.loader",
    })
  end)

  after_each(function()
    test_utils.restore_all({
      module_name,
      "theme-browser.adapters.base",
      "theme-browser.package_manager.manager",
      "theme-browser.preview.manager",
      "theme-browser.adapters.registry",
      "theme-browser.runtime.loader",
    })
  end)

  describe("use function", function()
    it("uses already available theme without install", function()
      local get_calls = setup_mocks({ load_success = true, can_manage = true })

      service = require(module_name)
      local result = service.use("tokyonight", "tokyonight-night", { notify = false })

      assert.is_true(result.ok)
      assert.equals(1, get_calls())
    end)

    it("installs missing theme then retries apply via callback", function()
      setup_mocks({ fail_first = true, fail_error = "theme is not cached or installed" })

      service = require(module_name)
      local callback_called = false
      local callback_result = nil

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

      vim.wait(2000, function()
        return callback_called
      end)

      assert.is_true(callback_called)
      assert.is_true(callback_result.success)
    end)

    it("returns initial failure when install is unavailable", function()
      setup_mocks({ fail_always = true, can_manage = false, no_resolve = true })

      service = require(module_name)
      local callback_called = false
      local callback_result = nil

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

      vim.wait(2000, function()
        return callback_called
      end)

      assert.is_true(callback_called)
      assert.is_false(callback_result.success)
    end)

    it("keeps install as alias to use", function()
      setup_mocks({ load_success = true, can_manage = true })

      service = require(module_name)
      local result = service.install("tokyonight", "tokyonight-night", { notify = false })
      assert.is_true(result.ok)
    end)
  end)

  describe("preview function", function()
    it("returns 0 on successful preview", function()
      setup_mocks({ load_success = true })

      service = require(module_name)
      local status = service.preview("tokyonight", "tokyonight-night", { notify = false })

      assert.equals(0, status)
    end)

    it("returns 0 and triggers async install for missing theme", function()
      setup_mocks({ fail_first = true })

      service = require(module_name)
      local status = service.preview("tokyonight", "tokyonight-night", { notify = false })

      assert.equals(0, status)
    end)

    it("returns 0 even when install unavailable (triggers github fallback)", function()
      setup_mocks({ fail_first = true, can_manage = false })

      service = require(module_name)
      local status = service.preview("tokyonight", "tokyonight-night", { notify = false })

      assert.equals(0, status)
    end)
  end)

  describe("conflict detection", function()
    it("warns when theme has conflicts in meta", function()
      local notify_mock = test_utils.mock_vim_notify()

      setup_mocks({
        fail_first = true,
        can_manage = false,
        meta = { source = "github", conflicts = { "habamax" } },
      })

      service = require(module_name)
      service.use("habamax", nil, { notify = true }, function() end)

      vim.wait(100)
      local found = notify_mock.has_warning("conflict")
      notify_mock.restore()

      assert.is_true(found)
    end)

    it("does not warn when theme has no conflicts", function()
      local notify_mock = test_utils.mock_vim_notify()

      setup_mocks({
        load_success = true,
        can_manage = true,
        meta = { source = "github" },
      })

      service = require(module_name)
      service.use("tokyonight", nil, { notify = true })

      vim.wait(50)
      local found = notify_mock.has_warning("conflict")
      notify_mock.restore()

      assert.is_false(found)
    end)

    it("handles multiple conflict names", function()
      local notify_mock = test_utils.mock_vim_notify()

      setup_mocks({
        fail_first = true,
        can_manage = false,
        meta = { source = "github", conflicts = { "blue", "darkblue" } },
      })

      service = require(module_name)
      service.use("test", nil, { notify = true }, function() end)

      vim.wait(100)
      local found = notify_mock.has_warning("blue") and notify_mock.has_warning("darkblue")
      notify_mock.restore()

      assert.is_true(found)
    end)
  end)
end)
