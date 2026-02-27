describe("theme-browser.runtime.loader", function()
  local module_name = "theme-browser.runtime.loader"
  local test_utils = require("tests.helpers.test_utils")
  local loader

  local function setup_mocks(registry_opts, pm_opts, github_opts, config_opts)
    registry_opts = registry_opts or {}
    pm_opts = pm_opts or {}
    github_opts = github_opts or {}
    config_opts = config_opts or {}

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function()
        return registry_opts.entry
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      load_entry = function()
        return pm_opts.load_success or false
      end,
      can_delegate_load = function()
        return pm_opts.can_delegate or false
      end,
    }

    local cache_dir = config_opts.cache_dir or vim.fn.tempname()
    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = cache_dir }
      end,
    }

    local default_cache_path = cache_dir .. "/owner__theme.nvim"
    package.loaded["theme-browser.downloader.github"] = {
      is_cached = function()
        return github_opts.is_cached or false
      end,
      get_cache_path = function()
        return github_opts.cache_path or default_cache_path
      end,
      resolve_cache_path = function()
        return github_opts.resolve_path or github_opts.cache_path or default_cache_path
      end,
    }

    return cache_dir
  end

  before_each(function()
    test_utils.reset_all({
      module_name,
      "theme-browser",
      "theme-browser.adapters.registry",
      "theme-browser.package_manager.manager",
      "theme-browser.downloader.github",
    })
  end)

  after_each(function()
    test_utils.restore_all({
      module_name,
      "theme-browser",
      "theme-browser.adapters.registry",
      "theme-browser.package_manager.manager",
      "theme-browser.downloader.github",
    })
  end)

  describe("builtin themes", function()
    it("succeeds immediately without cache check", function()
      setup_mocks({
        entry = test_utils.make_theme_entry("default", { builtin = true, colorscheme = "default" }),
      })

      loader = require(module_name)
      local success, err, runtime_path
      loader.ensure_available("default", nil, function(ok, callback_err, path)
        success = ok
        err = callback_err
        runtime_path = path
      end)

      vim.wait(20)
      assert.is_true(success)
      assert.is_nil(err)
      assert.equals("builtin", runtime_path)
    end)

    it("fails when theme cannot be resolved", function()
      setup_mocks({ entry = nil })

      loader = require(module_name)
      local success, err
      loader.ensure_available("nonexistent", nil, function(ok, callback_err)
        success = ok
        err = callback_err
      end)

      vim.wait(20)
      assert.is_false(success)
      assert.equals("theme not found in index", err)
    end)
  end)

  describe("plugin themes", function()
    it("fails fast when theme is not cached", function()
      local cache_dir = setup_mocks({
        entry = test_utils.make_theme_entry("demo", { repo = "owner/theme.nvim" }),
      }, { can_delegate = false })

      loader = require(module_name)
      local success, err
      loader.ensure_available("demo", nil, function(ok, callback_err)
        success = ok
        err = callback_err
      end)

      vim.wait(20)
      assert.is_false(success)
      assert.equals("theme is not cached or installed", err)
      vim.fn.delete(cache_dir, "rf")
    end)

    it("uses resolved cache path for cached themes", function()
      local cache_dir = setup_mocks({
        entry = test_utils.make_theme_entry("demo", { repo = "owner/theme.nvim" }),
      }, {}, {
        is_cached = true,
        resolve_path = vim.fn.tempname(),
      })
      local cache_path = package.loaded["theme-browser.downloader.github"].resolve_cache_path()
      vim.fn.mkdir(cache_path, "p")

      loader = require(module_name)
      local success, runtime_path
      loader.ensure_available("demo", nil, function(ok, _, path)
        success = ok
        runtime_path = path
      end)

      vim.wait(100)
      assert.is_true(success)
      assert.equals(cache_path, runtime_path)
      assert.is_truthy(vim.o.runtimepath:find(cache_path, 1, true))

      vim.fn.delete(cache_dir, "rf")
    end)

    it("prepends runtimepath only once for repeated loads", function()
      local cache_dir = setup_mocks({
        entry = test_utils.make_theme_entry("demo", { repo = "owner/theme.nvim" }),
      }, {}, {
        is_cached = true,
      })
      local cache_path = package.loaded["theme-browser.downloader.github"].get_cache_path()
      vim.fn.mkdir(cache_path, "p")

      loader = require(module_name)
      local calls = 0
      loader.ensure_available("demo", nil, function(ok)
        if ok then
          calls = calls + 1
        end
      end)
      loader.ensure_available("demo", nil, function(ok)
        if ok then
          calls = calls + 1
        end
      end)

      vim.wait(100)
      assert.equals(2, calls)

      local count = 0
      for _, path in ipairs(vim.opt.runtimepath:get()) do
        if path == cache_path then
          count = count + 1
        end
      end
      assert.equals(1, count)

      vim.fn.delete(cache_dir, "rf")
    end)

    it("resets lua loader cache after adding runtimepath", function()
      local cache_dir = setup_mocks({
        entry = test_utils.make_theme_entry("demo", { repo = "owner/theme.nvim" }),
      }, {}, {
        is_cached = true,
      })
      local cache_path = package.loaded["theme-browser.downloader.github"].get_cache_path()
      vim.fn.mkdir(cache_path, "p")

      local original_loader = vim.loader
      local reset_calls = 0
      vim.loader = {
        reset = function()
          reset_calls = reset_calls + 1
        end,
      }

      loader = require(module_name)
      local success = false
      loader.ensure_available("demo", nil, function(ok)
        success = ok
      end)

      vim.wait(100)
      vim.loader = original_loader
      assert.is_true(success)
      assert.equals(1, reset_calls)

      vim.fn.delete(cache_dir, "rf")
    end)
  end)

  describe("source detection", function()
    it("recognizes builtin via meta.source neovim", function()
      setup_mocks({
        entry = {
          name = "blue",
          colorscheme = "blue",
          meta = { source = "neovim", strategy = { type = "colorscheme" } },
        },
      })

      loader = require(module_name)
      local success, err, runtime_path
      loader.ensure_available("blue", nil, function(ok, callback_err, path)
        success = ok
        err = callback_err
        runtime_path = path
      end)

      vim.wait(20)
      assert.is_true(success)
      assert.is_nil(err)
      assert.equals("builtin", runtime_path)
    end)

    it("recognizes external via meta.source github", function()
      local cache_dir = setup_mocks({
        entry = {
          name = "nonexistent-theme",
          repo = "owner/nonexistent-theme.nvim",
          meta = { source = "github", strategy = { type = "setup" } },
        },
      })

      loader = require(module_name)
      local success, err
      loader.ensure_available("tokyonight", nil, function(ok, callback_err)
        success = ok
        err = callback_err
      end)

      vim.wait(20)
      assert.is_false(success)
      assert.equals("theme is not cached or installed", err)

      vim.fn.delete(cache_dir, "rf")
    end)

    it("falls back to builtin field for backward compat", function()
      setup_mocks({
        entry = test_utils.make_theme_entry("default", { builtin = true, colorscheme = "default" }),
      })

      loader = require(module_name)
      local success, err, runtime_path
      loader.ensure_available("default", nil, function(ok, callback_err, path)
        success = ok
        err = callback_err
        runtime_path = path
      end)

      vim.wait(20)
      assert.is_true(success)
      assert.is_nil(err)
      assert.equals("builtin", runtime_path)
    end)
  end)
end)
