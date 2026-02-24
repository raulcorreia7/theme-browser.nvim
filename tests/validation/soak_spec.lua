describe("theme-browser.validation.soak", function()
  local module_name = "theme-browser.validation.soak"
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

  local function mock_time()
    return math.floor(vim.loop.hrtime() / 1e6)
  end

  before_each(function()
    snapshots = {}
    snapshot(module_name)
    snapshot("theme-browser")
    snapshot("theme-browser.adapters.registry")
    snapshot("theme-browser.persistence.state")
    snapshot("theme-browser.application.theme_service")
    snapshot("theme-browser.package_manager.manager")
    snapshot("theme-browser.downloader.github")

    package.loaded[module_name] = nil
  end)

  after_each(function()
    restore(module_name)
    restore("theme-browser")
    restore("theme-browser.adapters.registry")
    restore("theme-browser.persistence.state")
    restore("theme-browser.application.theme_service")
    restore("theme-browser.package_manager.manager")
    restore("theme-browser.downloader.github")
  end)

  it("produces a report by iterating registry entries", function()
    package.loaded["theme-browser"] = {
      get_config = function()
        return {
          cache_dir = vim.fn.stdpath("cache") .. "/theme-browser-test",
        }
      end,
    }

    local entries = {
      { id = "a", name = "theme-a", variant = nil, repo = "owner/a" },
      { id = "b", name = "theme-b", variant = "theme-b-dark", repo = "owner/b" },
    }

    package.loaded["theme-browser.adapters.registry"] = {
      list_entries = function()
        return entries
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      build_state_snapshot = function()
        return {}
      end,
      get_entry_state = function()
        return { installed = true, cached = true }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      install_theme = function()
        return true
      end,
    }

    -- Track current colorscheme through the test
    local current_colorscheme = nil

    package.loaded["theme-browser.application.theme_service"] = {
      preview = function(name, variant)
        current_colorscheme = variant or name
        vim.g.colors_name = current_colorscheme
        return 0
      end,
      use = function(name, variant)
        current_colorscheme = variant or name
        vim.g.colors_name = current_colorscheme
        return { ok = true }
      end,
    }

    vim.g.colors_name = nil

    local output_path = vim.fn.tempname() .. ".json"
    local soak = require(module_name)
    local report = soak.run({ output_path = output_path })

    assert.is_true(report.ok)
    assert.equals(2, report.total_entries)
    assert.equals(2, report.ok_count)
    assert.equals(0, report.fail_count)
    assert.equals(0, report.notify_count)
    assert.is_true(vim.fn.filereadable(output_path) == 1)
  end)

  it("supports configurable timeout via opts", function()
    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = "/tmp/test" }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      list_entries = function()
        return {}
      end,
    }

    local soak = require(module_name)
    local report = soak.run({ timeout_ms = 600000 })

    assert.is_true(report.ok)
  end)

  it("calls progress callback during validation", function()
    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = vim.fn.stdpath("cache") .. "/theme-browser-test" }
      end,
    }

    local entries = {
      { id = "a", name = "theme-a", variant = nil, repo = "owner/a" },
    }

    package.loaded["theme-browser.adapters.registry"] = {
      list_entries = function()
        return entries
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      build_state_snapshot = function()
        return {}
      end,
      get_entry_state = function()
        return { installed = true, cached = true }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      install_theme = function()
        return true
      end,
    }

    package.loaded["theme-browser.application.theme_service"] = {
      preview = function(name)
        vim.g.colors_name = name
        return 0
      end,
      use = function(name)
        vim.g.colors_name = name
        return { ok = true }
      end,
    }

    vim.g.colors_name = "theme-a"

    local progress_calls = {}
    local soak = require(module_name)
    local report = soak.run({
      on_progress = function(done, total, current_name, status)
        table.insert(progress_calls, {
          done = done,
          total = total,
          name = current_name,
          status = status,
        })
      end,
    })

    assert.is_true(report.ok)
    assert.is_true(#progress_calls > 0)
    assert.equals("theme-a", progress_calls[#progress_calls].name)
  end)

  it("validates colorscheme actually changes after apply", function()
    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = vim.fn.stdpath("cache") .. "/theme-browser-test" }
      end,
    }

    local entries = {
      { id = "a", name = "theme-a", variant = nil, repo = "owner/a" },
    }

    package.loaded["theme-browser.adapters.registry"] = {
      list_entries = function()
        return entries
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      build_state_snapshot = function()
        return {}
      end,
      get_entry_state = function()
        return { installed = true, cached = true }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      install_theme = function()
        return true
      end,
    }

    package.loaded["theme-browser.application.theme_service"] = {
      preview = function()
        return 0
      end,
      use = function(name)
        vim.g.colors_name = name
        return { ok = true }
      end,
    }

    vim.g.colors_name = "theme-a"

    local soak = require(module_name)
    local report = soak.run({})

    assert.is_true(report.ok)
    assert.equals(1, report.ok_count)
    assert.is_not_nil(report.items[1])
    assert.is_true(report.items[1].colorscheme_ok)
  end)

  it("reports failure when colorscheme does not match expected", function()
    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = vim.fn.stdpath("cache") .. "/theme-browser-test" }
      end,
    }

    local entries = {
      { id = "a", name = "theme-a", variant = nil, repo = "owner/a" },
    }

    package.loaded["theme-browser.adapters.registry"] = {
      list_entries = function()
        return entries
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      build_state_snapshot = function()
        return {}
      end,
      get_entry_state = function()
        return { installed = true, cached = true }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      install_theme = function()
        return true
      end,
    }

    package.loaded["theme-browser.application.theme_service"] = {
      preview = function()
        return 0
      end,
      use = function()
        return { ok = true }
      end,
    }

    vim.g.colors_name = "wrong-theme"

    local soak = require(module_name)
    local report = soak.run({})

    assert.is_false(report.ok)
    assert.equals(0, report.ok_count)
    assert.equals(1, report.fail_count)
    assert.is_not_nil(report.items[1])
    assert.is_false(report.items[1].colorscheme_ok)
  end)

  it("saves and resumes from checkpoint", function()
    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = vim.fn.stdpath("cache") .. "/theme-browser-test" }
      end,
    }

    local entries = {
      { id = "a", name = "theme-a", variant = nil, repo = "owner/a" },
      { id = "b", name = "theme-b", variant = nil, repo = "owner/b" },
      { id = "c", name = "theme-c", variant = nil, repo = "owner/c" },
    }

    package.loaded["theme-browser.adapters.registry"] = {
      list_entries = function()
        return entries
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      build_state_snapshot = function()
        return {}
      end,
      get_entry_state = function()
        return { installed = true, cached = true }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      install_theme = function()
        return true
      end,
    }

    package.loaded["theme-browser.application.theme_service"] = {
      preview = function()
        return 0
      end,
      use = function(name)
        vim.g.colors_name = name
        return { ok = true }
      end,
    }

    local checkpoint_path = vim.fn.tempname() .. "-checkpoint.json"

    vim.g.colors_name = "theme-a"

    local soak = require(module_name)
    local report1 = soak.run({
      checkpoint_path = checkpoint_path,
    })

    assert.is_true(report1.ok)
    assert.is_false(report1.resumed_from_checkpoint)
    assert.equals(3, report1.total_entries)
    assert.equals(3, report1.ok_count)

    assert.is_true(vim.fn.filereadable(checkpoint_path) ~= 1)

    local file = io.open(checkpoint_path, "w")
    file:write(vim.json.encode({ 
      last_index = 1, 
      items = { { name = "theme-a", ok = true } }, 
      started_at_ms = mock_time() 
    }))
    file:close()

    local report2 = soak.run({
      checkpoint_path = checkpoint_path,
    })

    assert.is_true(report2.resumed_from_checkpoint)
    assert.equals(1, report2.start_index)
  end)
end)
