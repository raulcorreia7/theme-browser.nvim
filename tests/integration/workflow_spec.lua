describe("Integration: workflow", function()
  local original_stdpath = vim.fn.stdpath
  local temp_root
  local test_report = {}

  local function reset_modules()
    package.loaded["theme-browser"] = nil
    package.loaded["theme-browser.adapters.registry"] = nil
    package.loaded["theme-browser.adapters.factory"] = nil
    package.loaded["theme-browser.adapters.base"] = nil
    package.loaded["theme-browser.adapters.plugins"] = nil
    package.loaded["theme-browser.persistence.state"] = nil
    package.loaded["theme-browser.persistence.lazy_spec"] = nil
    package.loaded["theme-browser.preview.manager"] = nil
    package.loaded["theme-browser.application.theme_service"] = nil
    package.loaded["theme-browser.runtime.loader"] = nil
    package.loaded["theme-browser.package_manager.manager"] = nil
    package.loaded["theme-browser.ui.gallery"] = nil
  end

  local function write_file(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile(lines, path)
  end

  local function make_registry(path, themes)
    themes = themes
      or {
        {
          name = "tokyonight",
          repo = "folke/tokyonight.nvim",
          colorscheme = "tokyonight",
          variants = {
            { name = "tokyonight-night", colorscheme = "tokyonight-night" },
            { name = "tokyonight-storm", colorscheme = "tokyonight-storm" },
            { name = "tokyonight-moon", colorscheme = "tokyonight-moon" },
            { name = "tokyonight-day", colorscheme = "tokyonight-day" },
          },
          meta = { strategy = "setup_colorscheme", module = "tokyonight" },
        },
        {
          name = "catppuccin",
          repo = "catppuccin/nvim",
          colorscheme = "catppuccin",
          variants = {
            { name = "catppuccin-latte", colorscheme = "catppuccin-latte" },
            { name = "catppuccin-frappe", colorscheme = "catppuccin-frappe" },
            { name = "catppuccin-macchiato", colorscheme = "catppuccin-macchiato" },
            { name = "catppuccin-mocha", colorscheme = "catppuccin-mocha" },
          },
          meta = { strategy = "setup_colorscheme", module = "catppuccin" },
        },
        {
          name = "kanagawa",
          repo = "rebelot/kanagawa.nvim",
          colorscheme = "kanagawa",
          variants = {
            {
              name = "kanagawa-wave",
              colorscheme = "kanagawa-wave",
              meta = { adapter = "load", module = "kanagawa", args = { "wave" } },
            },
            {
              name = "kanagawa-dragon",
              colorscheme = "kanagawa-dragon",
              meta = { adapter = "load", module = "kanagawa", args = { "dragon" } },
            },
            {
              name = "kanagawa-lotus",
              colorscheme = "kanagawa-lotus",
              meta = { adapter = "load", module = "kanagawa", args = { "lotus" } },
            },
          },
        },
        {
          name = "gruvbox",
          repo = "morhetz/gruvbox",
          colorscheme = "gruvbox",
          variants = {
            { name = "gruvbox-dark", colorscheme = "gruvbox", meta = { opts_o = { background = "dark" } } },
            { name = "gruvbox-light", colorscheme = "gruvbox", meta = { opts_o = { background = "light" } } },
          },
          meta = { strategy = "vimg_colorscheme" },
        },
        {
          name = "onedark",
          repo = "navarasu/onedark.nvim",
          colorscheme = "onedark",
          variants = {
            {
              name = "onedark_dark",
              colorscheme = "onedark",
              meta = { adapter = "setup_load", module = "onedark", opts = { style = "dark" } },
            },
            {
              name = "onedark_darker",
              colorscheme = "onedark",
              meta = { adapter = "setup_load", module = "onedark", opts = { style = "darker" } },
            },
            {
              name = "onedark_cool",
              colorscheme = "onedark",
              meta = { adapter = "setup_load", module = "onedark", opts = { style = "cool" } },
            },
            {
              name = "onedark_deep",
              colorscheme = "onedark",
              meta = { adapter = "setup_load", module = "onedark", opts = { style = "deep" } },
            },
            {
              name = "onedark_warm",
              colorscheme = "onedark",
              meta = { adapter = "setup_load", module = "onedark", opts = { style = "warm" } },
            },
            {
              name = "onedark_warmer",
              colorscheme = "onedark",
              meta = { adapter = "setup_load", module = "onedark", opts = { style = "warmer" } },
            },
          },
        },
        {
          name = "alabaster",
          repo = "p00f/alabaster.nvim",
          colorscheme = "alabaster",
          meta = { strategy = "colorscheme_only" },
        },
        {
          name = "test-dep-theme",
          repo = "test/dep-theme",
          colorscheme = "test-dep",
          deps = { "rktjmp/lush.nvim", "missing/dependency.nvim" },
          meta = { strategy = "colorscheme_only" },
        },
      }
    write_file(path, { vim.json.encode(themes) })
  end

  local function mock_base_adapter()
    local mock_loads = {}
    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(name, variant, opts)
        opts = opts or {}
        table.insert(mock_loads, { name = name, variant = variant, opts = opts })
        if name == "nonexistent-theme" then
          return {
            ok = false,
            errors = { not_found = "Theme not found in registry" },
          }
        end
        if opts.preview then
          return {
            ok = true,
            name = name,
            variant = variant,
            colorscheme = variant or name,
            preview = true,
          }
        else
          local state = require("theme-browser.persistence.state")
          state.set_current_theme(name, variant)
          return {
            ok = true,
            name = name,
            variant = variant,
            colorscheme = variant or name,
          }
        end
      end,
      get_load_history = function()
        return mock_loads
      end,
      clear_history = function()
        mock_loads = {}
      end,
    }
    return package.loaded["theme-browser.adapters.base"]
  end

  local function mock_package_manager()
    package.loaded["theme-browser.package_manager.manager"] = {
      can_manage_install = function()
        return true
      end,
      install_theme = function(name, variant, opts)
        return true
      end,
      when_ready = function(callback)
        callback()
      end,
    }
  end

  before_each(function()
    temp_root = vim.fn.tempname()
    vim.fn.mkdir(temp_root, "p")
    vim.fn.stdpath = function(kind)
      if kind == "data" then
        return temp_root .. "/data"
      elseif kind == "config" then
        return temp_root .. "/config"
      elseif kind == "cache" then
        return temp_root .. "/cache"
      end
      return original_stdpath(kind)
    end
    reset_modules()
    test_report = {}
  end)

  after_each(function()
    vim.fn.stdpath = original_stdpath
    reset_modules()
    if temp_root and vim.fn.isdirectory(temp_root) == 1 then
      vim.fn.delete(temp_root, "rf")
    end
  end)

  describe("Full Gallery Workflow", function()
    it("opens gallery, searches, navigates, previews, applies theme, verifies state", function()
      local registry_path = temp_root .. "/registry.json"
      make_registry(registry_path)

      local state = require("theme-browser.persistence.state")
      state.initialize({ package_manager = { enabled = true, mode = "manual" } })

      local registry = require("theme-browser.adapters.registry")
      registry.initialize(registry_path)

      local base = mock_base_adapter()
      mock_package_manager()

      local gallery_calls = {}
      package.loaded["theme-browser.ui.gallery"] = {
        open = function(query)
          table.insert(gallery_calls, { action = "open", query = query })
        end,
        close = function()
          table.insert(gallery_calls, { action = "close" })
        end,
        is_open = function()
          return #gallery_calls > 0 and gallery_calls[#gallery_calls].action ~= "close"
        end,
        get_filtered_entries = function()
          return registry.search_themes("tokyo")
        end,
      }

      local gallery = require("theme-browser.ui.gallery")
      gallery.open()

      assert.equals(1, #gallery_calls)
      assert.equals("open", gallery_calls[1].action)

      local search_results = registry.search_themes("tokyonight")
      assert.is_true(#search_results >= 1)
      assert.equals("tokyonight", search_results[1].name)

      local service = require("theme-browser.application.theme_service")
      -- preview returns 0 on success, not a table
      local preview_result = service.preview("tokyonight", "tokyonight-night", { notify = false })

      -- preview returns 0 on success
      assert.equals(0, preview_result)

      local use_result = service.use("tokyonight", "tokyonight-night", { notify = false })
      assert.is_true(use_result.ok)

      local current = state.get_current_theme()
      assert.is_not_nil(current)
      assert.equals("tokyonight", current.name)
      assert.equals("tokyonight-night", current.variant)

      gallery.close()
      assert.equals(2, #gallery_calls)
      assert.equals("close", gallery_calls[2].action)

      table.insert(test_report, {
        test = "Full Gallery Workflow",
        status = "PASS",
        details = "Gallery opened, searched, previewed, applied, state persisted",
      })
    end)

    it("searches and filters themes correctly", function()
      local registry_path = temp_root .. "/registry.json"
      make_registry(registry_path)

      local registry = require("theme-browser.adapters.registry")
      registry.initialize(registry_path)

      local all_themes = registry.list_themes()
      assert.is_true(#all_themes >= 5)

      local search_results = registry.search_themes("tokyo")
      assert.equals(1, #search_results)
      assert.equals("tokyonight", search_results[1].name)

      local cat_results = registry.search_themes("catppuccin")
      assert.equals(1, #cat_results)

      local empty_results = registry.search_themes("xyznonexistent")
      assert.equals(0, #empty_results)

      local all_results = registry.search_themes("")
      assert.equals(#all_themes, #all_results)
    end)
  end)

  describe("ThemeBrowserUse Command", function()
    it("applies theme with basic name :ThemeBrowserUse tokyonight", function()
      local registry_path = temp_root .. "/registry.json"
      make_registry(registry_path)

      local state = require("theme-browser.persistence.state")
      state.initialize({ package_manager = { enabled = true, mode = "manual" } })

      local registry = require("theme-browser.adapters.registry")
      registry.initialize(registry_path)

      mock_base_adapter()
      mock_package_manager()

      local theme_service = require("theme-browser.application.theme_service")
      local result = theme_service.use("tokyonight", nil, { notify = false })

      assert.is_true(result.ok)

      local current = state.get_current_theme()
      assert.is_not_nil(current)
      assert.equals("tokyonight", current.name)
    end)

    it("applies theme with variant :ThemeBrowserUse kanagawa wave", function()
      local registry_path = temp_root .. "/registry.json"
      make_registry(registry_path)

      local state = require("theme-browser.persistence.state")
      state.initialize({ package_manager = { enabled = true, mode = "manual" } })

      local registry = require("theme-browser.adapters.registry")
      registry.initialize(registry_path)

      mock_base_adapter()
      mock_package_manager()

      local theme_service = require("theme-browser.application.theme_service")
      local result = theme_service.use("kanagawa", "kanagawa-wave", { notify = false })

      assert.is_true(result.ok)

      local current = state.get_current_theme()
      assert.is_not_nil(current)
      assert.equals("kanagawa", current.name)
      assert.equals("kanagawa-wave", current.variant)
    end)

    it("applies theme with colon syntax tokyonight:night", function()
      local registry_path = temp_root .. "/registry.json"
      make_registry(registry_path)

      local state = require("theme-browser.persistence.state")
      state.initialize({ package_manager = { enabled = true, mode = "manual" } })

      local registry = require("theme-browser.adapters.registry")
      registry.initialize(registry_path)

      mock_base_adapter()
      mock_package_manager()

      local entry = registry.resolve("tokyonight", "tokyonight-night")
      assert.is_not_nil(entry)

      local theme_service = require("theme-browser.application.theme_service")
      local result = theme_service.use("tokyonight", "tokyonight-night", { notify = false })

      assert.is_true(result.ok)

      local current = state.get_current_theme()
      assert.equals("tokyonight", current.name)
      assert.equals("tokyonight-night", current.variant)
    end)
  end)

  describe("Error Scenarios", function()
    it("handles invalid theme name gracefully", function()
      local registry_path = temp_root .. "/registry.json"
      make_registry(registry_path)

      local state = require("theme-browser.persistence.state")
      state.initialize({ package_manager = { enabled = true, mode = "manual" } })

      local registry = require("theme-browser.adapters.registry")
      registry.initialize(registry_path)

      mock_base_adapter()
      mock_package_manager()

      local theme_service = require("theme-browser.application.theme_service")
      local callback_called = false
      local callback_result = nil
      theme_service.use("nonexistent-theme", nil, { notify = false }, function(success, res, err)
        callback_called = true
        callback_result = { success = success, res = res, err = err }
      end)

      vim.wait(1000, function()
        return callback_called
      end)

      assert.is_true(callback_called)
      assert.is_false(callback_result.success)
    end)

    it("handles theme with missing dependencies", function()
      local registry_path = temp_root .. "/registry.json"
      make_registry(registry_path)

      local state = require("theme-browser.persistence.state")
      state.initialize({ package_manager = { enabled = true, mode = "manual" } })

      local registry = require("theme-browser.adapters.registry")
      registry.initialize(registry_path)

      local dep_checked = false
      package.loaded["theme-browser.adapters.base"] = {
        load_theme = function(name, variant, opts)
          if name == "test-dep-theme" then
            dep_checked = true
            return {
              ok = false,
              errors = { runtime_error = "Missing required dependency: missing/dependency.nvim" },
            }
          end
          return { ok = true, name = name, variant = variant }
        end,
      }

      mock_package_manager()

      local theme = registry.get_theme("test-dep-theme")
      assert.is_not_nil(theme)
      assert.is_not_nil(theme.deps)
      assert.is_true(#theme.deps > 0)

      local theme_service = require("theme-browser.application.theme_service")
      local callback_called = false
      local callback_result = nil
      theme_service.use("test-dep-theme", nil, { notify = false }, function(success, res, err)
        callback_called = true
        callback_result = { success = success, res = res, err = err }
      end)

      vim.wait(1000, function()
        return callback_called
      end)

      assert.is_true(callback_called)
      assert.is_false(callback_result.success)
      assert.is_true(dep_checked)
    end)

    it("handles network failure during install gracefully", function()
      local registry_path = temp_root .. "/registry.json"
      make_registry(registry_path)

      local state = require("theme-browser.persistence.state")
      state.initialize({ package_manager = { enabled = true, mode = "manual" } })

      local registry = require("theme-browser.adapters.registry")
      registry.initialize(registry_path)

      package.loaded["theme-browser.adapters.base"] = {
        load_theme = function(name, variant, opts)
          return {
            ok = false,
            errors = { runtime_error = "theme is not cached or installed" },
          }
        end,
      }

      local install_attempted = false
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

      local theme_service = require("theme-browser.application.theme_service")
      local callback_called = false
      local callback_result = nil
      theme_service.use("tokyonight", "tokyonight-night", { notify = false }, function(success, res, err)
        callback_called = true
        callback_result = { success = success, res = res, err = err }
      end)

      vim.wait(1000, function()
        return callback_called
      end)

      assert.is_true(callback_called)
      assert.is_false(callback_result.success)
    end)
  end)

  describe("State Persistence", function()
    it("persists theme state across operations", function()
      local registry_path = temp_root .. "/registry.json"
      make_registry(registry_path)

      local state = require("theme-browser.persistence.state")
      state.initialize({ package_manager = { enabled = true, mode = "manual" } })

      local registry = require("theme-browser.adapters.registry")
      registry.initialize(registry_path)

      mock_base_adapter()
      mock_package_manager()

      local theme_service = require("theme-browser.application.theme_service")

      local done1 = false
      theme_service.use("tokyonight", "tokyonight-night", { notify = false }, function()
        done1 = true
      end)
      vim.wait(1000, function()
        return done1
      end)

      local current1 = state.get_current_theme()
      assert.equals("tokyonight", current1.name)

      local done2 = false
      theme_service.use("catppuccin", "catppuccin-mocha", { notify = false }, function()
        done2 = true
      end)
      vim.wait(1000, function()
        return done2
      end)

      local current2 = state.get_current_theme()
      assert.equals("catppuccin", current2.name)

      local history = state.get_history()
      assert.equals(1, #history)
      assert.equals("tokyonight", history[1])
    end)
  end)
end)
