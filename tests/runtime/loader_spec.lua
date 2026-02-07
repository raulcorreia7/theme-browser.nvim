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

  it("does not short-circuit through package manager in plugin_only mode", function()
    local temp_dir = vim.fn.tempname()
    local cache_path = temp_dir .. "/owner__theme.nvim"
    local called = { download = 0, load_entry = 0 }

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
        return cache_path
      end,
      download = function(_, _, cb, _)
        called.download = called.download + 1
        vim.fn.mkdir(cache_path, "p")
        cb(true, nil)
      end,
    }

    local loader = require(module_name)
    local success = nil
    loader.ensure_available("demo", nil, { notify = false, reason = "test" }, function(ok, _)
      success = ok
    end)

    vim.wait(100)
    assert.equals(1, called.download)
    assert.equals(0, called.load_entry)
    assert.is_true(success)
    assert.is_truthy(vim.o.runtimepath:find(cache_path, 1, true))

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
      download = function(_, _, cb, _)
        cb(false, "should not download")
      end,
    }

    local loader = require(module_name)
    local success, runtime_path
    loader.ensure_available("demo", nil, { notify = false }, function(ok, _, path)
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
      download = function(_, _, cb, _)
        cb(false, "should not download")
      end,
    }

    local loader = require(module_name)
    local calls = 0
    loader.ensure_available("demo", nil, { notify = false }, function(ok)
      if ok then
        calls = calls + 1
      end
    end)
    loader.ensure_available("demo", nil, { notify = false }, function(ok)
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
end)
