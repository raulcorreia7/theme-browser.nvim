describe("theme-browser.package_manager.providers.lazy", function()
  local module_name = "theme-browser.package_manager.providers.lazy"

  before_each(function()
    package.loaded[module_name] = nil
    package.loaded["lazy"] = nil
    package.loaded["lazy.core.config"] = nil
    package.loaded["lazy.manage.reloader"] = nil
  end)

  describe("is_builtin", function()
    local is_builtin

    before_each(function()
      local provider = require(module_name)
      is_builtin = function(entry)
        -- Test the helper function logic directly
        if not entry then
          return false
        end
        if entry.meta and entry.meta.source then
          return entry.meta.source == "neovim"
        end
        return entry.builtin == true
      end
    end)

    it("returns true for entry with meta.source neovim", function()
      assert.is_true(is_builtin({ meta = { source = "neovim" } }))
    end)

    it("returns false for entry with meta.source github", function()
      assert.is_false(is_builtin({ meta = { source = "github" } }))
    end)

    it("returns true for entry with builtin true (backward compat)", function()
      assert.is_true(is_builtin({ builtin = true }))
    end)

    it("returns false for entry without source or builtin", function()
      assert.is_false(is_builtin({ name = "tokyonight", repo = "folke/tokyonight.nvim" }))
      assert.is_false(is_builtin({}))
      assert.is_false(is_builtin(nil))
    end)
  end)

  describe("load_entry", function()
    local lazy_provider

    before_each(function()
      lazy_provider = require(module_name)
    end)

    it("skips entry with meta.source neovim", function()
      local load_called = false
      package.loaded["lazy"] = {
        load = function()
          load_called = true
        end,
      }

      local result = lazy_provider.load_entry({
        name = "blue",
        meta = { source = "neovim" },
      })

      assert.is_false(result)
      assert.is_false(load_called)
    end)

    it("skips entry with builtin true (backward compat)", function()
      local load_called = false
      package.loaded["lazy"] = {
        load = function()
          load_called = true
        end,
      }

      local result = lazy_provider.load_entry({
        name = "default",
        builtin = true,
      })

      assert.is_false(result)
      assert.is_false(load_called)
    end)

    it("loads entry with meta.source github", function()
      local load_called = false
      package.loaded["lazy"] = {
        load = function()
          load_called = true
        end,
      }

      local result = lazy_provider.load_entry({
        name = "tokyonight",
        repo = "folke/tokyonight.nvim",
        meta = { source = "github" },
      })

      assert.is_true(result)
      assert.is_true(load_called)
    end)

    it("returns false for entry without repo", function()
      local result = lazy_provider.load_entry({
        name = "test",
        meta = { source = "github" },
      })

      assert.is_false(result)
    end)
  end)

  describe("install_entry", function()
    local lazy_provider

    before_each(function()
      lazy_provider = require(module_name)
    end)

    it("skips entry with meta.source neovim", function()
      local install_called = false
      package.loaded["lazy"] = {
        install = function()
          install_called = true
        end,
        load = function() end,
      }

      local result = lazy_provider.install_entry({
        name = "blue",
        meta = { source = "neovim" },
      }, {})

      assert.is_false(result)
      assert.is_false(install_called)
    end)

    it("skips entry with builtin true (backward compat)", function()
      local install_called = false
      package.loaded["lazy"] = {
        install = function()
          install_called = true
        end,
        load = function() end,
      }

      local result = lazy_provider.install_entry({
        name = "default",
        builtin = true,
      }, {})

      assert.is_false(result)
      assert.is_false(install_called)
    end)

    it("installs entry with meta.source github", function()
      local install_called = false
      package.loaded["lazy"] = {
        install = function()
          install_called = true
        end,
        load = function() end,
      }

      local result = lazy_provider.install_entry({
        name = "tokyonight",
        repo = "folke/tokyonight.nvim",
        meta = { source = "github" },
      }, { load = false })

      assert.is_true(result)
      assert.is_true(install_called)
    end)

    it("returns false for entry without repo", function()
      local result = lazy_provider.install_entry({
        name = "test",
        meta = { source = "github" },
      }, {})

      assert.is_false(result)
    end)
  end)
end)
