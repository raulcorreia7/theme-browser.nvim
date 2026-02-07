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
    snapshot("theme-browser.runtime.loader")
    snapshot("theme-browser.persistence.lazy_spec")
    snapshot("theme-browser.persistence.state")
    snapshot("theme-browser.adapters.registry")
    snapshot("theme-browser.package_manager.manager")
    snapshot("theme-browser.preview.manager")

    package.loaded[module_name] = nil
  end)

  after_each(function()
    restore(module_name)
    restore("theme-browser.adapters.base")
    restore("theme-browser.runtime.loader")
    restore("theme-browser.persistence.lazy_spec")
    restore("theme-browser.persistence.state")
    restore("theme-browser.adapters.registry")
    restore("theme-browser.package_manager.manager")
    restore("theme-browser.preview.manager")
  end)

  it("marks theme and starts install prefetch in background", function()
    local marked = nil
    local prefetch = nil
    local applied = nil

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(name, variant, _)
        applied = { name = name, variant = variant }
        return { ok = true }
      end,
    }

    package.loaded["theme-browser.runtime.loader"] = {
      ensure_available = function(name, variant, opts, callback)
        prefetch = { name = name, variant = variant, opts = opts }
        callback(true, nil, nil)
      end,
    }

    package.loaded["theme-browser.persistence.lazy_spec"] = {
      generate_spec = function(_, _, _)
        return "/tmp/theme-browser-selected.lua"
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      mark_theme = function(name, variant)
        marked = { name = name, variant = variant }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "tokyonight", variant = "night" }
      end,
    }

    local service = require(module_name)
    local out = service.install("tokyonight", "tokyonight-night", { notify = false })
    vim.wait(120)

    assert.equals("/tmp/theme-browser-selected.lua", out)
    assert.is_not_nil(marked)
    assert.equals("tokyonight", marked.name)
    assert.equals("night", marked.variant)
    assert.is_not_nil(applied)
    assert.equals("tokyonight", applied.name)
    assert.equals("tokyonight-night", applied.variant)
    assert.is_not_nil(prefetch)
    assert.equals("tokyonight", prefetch.name)
    assert.equals("tokyonight-night", prefetch.variant)
    assert.equals("install", prefetch.opts.reason)
    assert.is_false(prefetch.opts.allow_package_manager)
  end)

  it("loads package manager in background when requested", function()
    local load_called = false
    local ready_called = false
    local install_opts = nil

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        return { ok = true }
      end,
    }

    package.loaded["theme-browser.runtime.loader"] = {
      ensure_available = function(_, _, _, callback)
        callback(true, nil, nil)
      end,
    }

    package.loaded["theme-browser.persistence.lazy_spec"] = {
      generate_spec = function(_, _, _)
        return "/tmp/theme-browser-selected.lua"
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      mark_theme = function(_) end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "tokyonight" }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      when_ready = function(callback)
        ready_called = true
        callback()
      end,
      install_theme = function(_, _, opts)
        install_opts = opts
        load_called = true
      end,
    }

    local service = require(module_name)
    service.install("tokyonight", "tokyonight-night", {
      notify = false,
      load_package_manager = true,
    })
    vim.wait(120)

    assert.is_true(ready_called)
    assert.is_true(load_called)
    assert.is_not_nil(install_opts)
    assert.is_true(install_opts.force)
    assert.is_true(install_opts.load)
  end)

  it("can skip apply-after-install when requested", function()
    local applied = false

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        applied = true
        return { ok = true }
      end,
    }

    package.loaded["theme-browser.runtime.loader"] = {
      ensure_available = function(_, _, _, callback)
        callback(true, nil, nil)
      end,
    }

    package.loaded["theme-browser.persistence.lazy_spec"] = {
      generate_spec = function(_, _, _)
        return "/tmp/theme-browser-selected.lua"
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      mark_theme = function(_, _) end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "tokyonight", variant = "night" }
      end,
    }

    local service = require(module_name)
    service.install("tokyonight", "tokyonight-night", {
      notify = false,
      apply_after_install = false,
      load_package_manager = false,
    })
    vim.wait(120)

    assert.is_false(applied)
  end)
end)
