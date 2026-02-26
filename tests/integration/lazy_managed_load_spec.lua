describe("Integration: lazy-managed theme loading", function()
  local test_utils = require("tests.helpers.test_utils")
  local base_module = "theme-browser.adapters.base"

  local original_notify = vim.notify
  local original_colorscheme = vim.cmd.colorscheme

  local modules = {
    "theme-browser.adapters.factory",
    "theme-browser.persistence.state",
    "theme-browser.persistence.lazy_spec",
    "theme-browser.adapters.registry",
    "lazy",
    base_module,
  }

  before_each(function()
    test_utils.reset_all(modules)
    vim.notify = function(_, _, _) end
    vim.cmd.colorscheme = function(_) end
  end)

  after_each(function()
    test_utils.restore_all(modules)
    vim.notify = original_notify
    vim.cmd.colorscheme = original_colorscheme
  end)

  it("does not retry through lazy-managed load path", function()
    local calls = {
      factory = 0,
      set_current = 0,
      gen_spec = 0,
      lazy_load = 0,
    }

    package.loaded["theme-browser.adapters.factory"] = {
      load_theme = function(_, _, _)
        calls.factory = calls.factory + 1
        if calls.factory == 1 then
          return {
            ok = false,
            errors = { colorscheme_error = "not loaded yet" },
          }
        end
        return {
          ok = true,
          name = "tokyonight",
          variant = "tokyonight-night",
          colorscheme = "tokyonight-night",
          strategy = "colorscheme_only",
          errors = {},
        }
      end,
      get_theme_status = function()
        return { installed = false }
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "auto" }
      end,
      set_current_theme = function(_, _)
        calls.set_current = calls.set_current + 1
      end,
    }

    package.loaded["theme-browser.persistence.lazy_spec"] = {
      generate_spec = function(_, _, _)
        calls.gen_spec = calls.gen_spec + 1
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return {
          name = "tokyonight",
          variant = "tokyonight-night",
          repo = "folke/tokyonight.nvim",
        }
      end,
    }

    package.loaded["lazy"] = {
      load = function(_)
        calls.lazy_load = calls.lazy_load + 1
      end,
    }

    package.loaded[base_module] = nil
    local base = require(base_module)
    local result = base.load_theme("tokyonight", "tokyonight-night", { notify = false })

    assert.is_false(result.ok)
    assert.equals(1, calls.factory)
    assert.equals(0, calls.set_current)
    assert.equals(0, calls.gen_spec)
    assert.equals(0, calls.lazy_load)
  end)

  it("does not persist lazy state in preview mode", function()
    local calls = {
      set_current = 0,
      gen_spec = 0,
      lazy_load = 0,
    }

    package.loaded["theme-browser.adapters.factory"] = {
      load_theme = function(_, _, _)
        return {
          ok = true,
          name = "tokyonight",
          variant = "tokyonight-night",
          colorscheme = "tokyonight-night",
          strategy = "colorscheme_only",
          errors = {},
        }
      end,
      get_theme_status = function()
        return { installed = false }
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      get_package_manager = function()
        return { enabled = true, mode = "auto" }
      end,
      set_current_theme = function(_, _)
        calls.set_current = calls.set_current + 1
      end,
    }

    package.loaded["theme-browser.persistence.lazy_spec"] = {
      generate_spec = function(_, _, _)
        calls.gen_spec = calls.gen_spec + 1
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return {
          name = "tokyonight",
          variant = "tokyonight-night",
          repo = "folke/tokyonight.nvim",
        }
      end,
    }

    package.loaded["lazy"] = {
      load = function(_)
        calls.lazy_load = calls.lazy_load + 1
      end,
    }

    package.loaded[base_module] = nil
    local base = require(base_module)
    local result = base.load_theme("tokyonight", "tokyonight-night", { preview = true, notify = false })

    assert.is_true(result.ok)
    assert.equals(0, calls.set_current)
    assert.equals(0, calls.gen_spec)
    assert.equals(0, calls.lazy_load)
  end)
end)
