describe("theme-browser.runtime.loader", function()
  local module_name = "theme-browser.runtime.loader"
  local snapshots = {}
  local runtimepath_before

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
    runtimepath_before = vim.o.runtimepath
    snapshot(module_name)
    snapshot("theme-browser")
    snapshot("theme-browser.adapters.registry")
    snapshot("theme-browser.package_manager.manager")
    snapshot("theme-browser.downloader.github")

    package.loaded[module_name] = nil
  end)

  after_each(function()
    vim.o.runtimepath = runtimepath_before
    restore(module_name)
    restore("theme-browser")
    restore("theme-browser.adapters.registry")
    restore("theme-browser.package_manager.manager")
    restore("theme-browser.downloader.github")
  end)

  it("fails fast when theme is not cached", function()
    local temp_dir = vim.fn.tempname()
    local called = { load_entry = 0 }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "demo", repo = "owner/theme.nvim" }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      load_entry = function(_)
        called.load_entry = called.load_entry + 1
        return true
      end,
      can_delegate_load = function()
        return false
      end,
    }

    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = temp_dir }
      end,
    }

    package.loaded["theme-browser.downloader.github"] = {
      is_cached = function(_, _)
        return false
      end,
      get_cache_path = function(_, _)
        return temp_dir .. "/owner__theme.nvim"
      end,
    }

    local loader = require(module_name)
    local success, err = nil, nil
    loader.ensure_available("demo", nil, function(ok, callback_err)
      success = ok
      err = callback_err
    end)

    vim.wait(20)
    assert.is_false(success)
    assert.equals("theme is not cached or installed", err)
    assert.equals(0, called.load_entry)

    vim.fn.delete(temp_dir, "rf")
  end)

  it("uses resolved cache path for legacy ownerless entries", function()
    local temp_dir = vim.fn.tempname()
    local legacy_path = temp_dir .. "/theme.nvim"
    vim.fn.mkdir(legacy_path, "p")

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "demo", repo = "owner/theme.nvim" }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      load_entry = function(_)
        return false
      end,
      can_delegate_load = function()
        return false
      end,
    }

    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = temp_dir }
      end,
    }

    package.loaded["theme-browser.downloader.github"] = {
      is_cached = function(_, _)
        return true
      end,
      resolve_cache_path = function(_, _)
        return legacy_path
      end,
    }

    local loader = require(module_name)
    local success, runtime_path
    loader.ensure_available("demo", nil, function(ok, _, path)
      success = ok
      runtime_path = path
    end)

    vim.wait(100)
    assert.is_true(success)
    assert.equals(legacy_path, runtime_path)
    assert.is_truthy(vim.o.runtimepath:find(legacy_path, 1, true))

    vim.fn.delete(temp_dir, "rf")
  end)

  it("prepends runtimepath only once for repeated loads", function()
    local temp_dir = vim.fn.tempname()
    local cache_path = temp_dir .. "/owner__theme.nvim"
    vim.fn.mkdir(cache_path, "p")

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "demo", repo = "owner/theme.nvim" }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      load_entry = function(_)
        return false
      end,
      can_delegate_load = function()
        return false
      end,
    }

    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = temp_dir }
      end,
    }

    package.loaded["theme-browser.downloader.github"] = {
      is_cached = function(_, _)
        return true
      end,
      resolve_cache_path = function(_, _)
        return cache_path
      end,
    }

    local loader = require(module_name)
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

    vim.fn.delete(temp_dir, "rf")
  end)

  it("succeeds immediately for builtin themes without cache check", function()
    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "default", colorscheme = "default", builtin = true }
      end,
    }

    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = "/nonexistent" }
      end,
    }

    local loader = require(module_name)
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

  it("fails for builtin themes that cannot be resolved", function()
    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return nil
      end,
    }

    local loader = require(module_name)
    local success, err
    loader.ensure_available("nonexistent", nil, function(ok, callback_err)
      success = ok
      err = callback_err
    end)

    vim.wait(20)
    assert.is_false(success)
    assert.equals("theme not found in index", err)
  end)

  describe("source detection", function()
    it("recognizes builtin via meta.source neovim", function()
      package.loaded["theme-browser.adapters.registry"] = {
        resolve = function(_, _)
          return {
            name = "blue",
            colorscheme = "blue",
            meta = { source = "neovim", strategy = { type = "colorscheme" } },
          }
        end,
      }

      package.loaded["theme-browser"] = {
        get_config = function()
          return { cache_dir = "/nonexistent" }
        end,
      }

      local loader = require(module_name)
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
      local temp_dir = vim.fn.tempname()

      package.loaded["theme-browser.adapters.registry"] = {
        resolve = function(_, _)
          return {
            name = "tokyonight",
            repo = "folke/tokyonight.nvim",
            meta = { source = "github", strategy = { type = "setup" } },
          }
        end,
      }

      package.loaded["theme-browser.package_manager.manager"] = {
        load_entry = function()
          return false
        end,
        can_delegate_load = function()
          return false
        end,
      }

      package.loaded["theme-browser"] = {
        get_config = function()
          return { cache_dir = temp_dir }
        end,
      }

      package.loaded["theme-browser.downloader.github"] = {
        is_cached = function()
          return false
        end,
        get_cache_path = function()
          return temp_dir .. "/folke__tokyonight.nvim"
        end,
      }

      local loader = require(module_name)
      local success, err
      loader.ensure_available("tokyonight", nil, function(ok, callback_err)
        success = ok
        err = callback_err
      end)

      vim.wait(20)
      assert.is_false(success)
      assert.equals("theme is not cached or installed", err)

      vim.fn.delete(temp_dir, "rf")
    end)

    it("falls back to builtin field for backward compat", function()
      package.loaded["theme-browser.adapters.registry"] = {
        resolve = function(_, _)
          return {
            name = "default",
            colorscheme = "default",
            builtin = true,
          }
        end,
      }

      package.loaded["theme-browser"] = {
        get_config = function()
          return { cache_dir = "/nonexistent" }
        end,
      }

      local loader = require(module_name)
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
