describe("theme-browser.validation.soak", function()
  local module_name = "theme-browser.validation.soak"
  local test_utils = require("tests.helpers.test_utils")
  local soak

  local function setup_mocks(entries, opts)
    opts = opts or {}
    local cache_dir = opts.cache_dir or (vim.fn.stdpath("cache") .. "/theme-browser-test")

    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = cache_dir }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      list_entries = function()
        return entries or {}
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      build_state_snapshot = function()
        return {}
      end,
      get_entry_state = function()
        return { installed = opts.installed ~= false, cached = opts.cached ~= false }
      end,
    }

    package.loaded["theme-browser.package_manager.manager"] = {
      install_theme = function()
        return opts.install_success ~= false
      end,
    }

    if opts.download_fail then
      package.loaded["theme-browser.downloader.github"] = {
        download = function(_, _, callback, _)
          callback(false, "network error")
        end,
      }
    end

    local current_colorscheme = nil
    package.loaded["theme-browser.application.theme_service"] = {
      preview = function(name)
        current_colorscheme = name
        return 0
      end,
      use = function(name, variant)
        current_colorscheme = variant or name
        if opts.set_colorscheme ~= false then
          vim.g.colors_name = current_colorscheme
        end
        return { ok = opts.use_success ~= false }
      end,
    }

    return function()
      return current_colorscheme
    end
  end

  before_each(function()
    test_utils.reset_all({
      module_name,
      "theme-browser",
      "theme-browser.adapters.registry",
      "theme-browser.persistence.state",
      "theme-browser.application.theme_service",
      "theme-browser.package_manager.manager",
      "theme-browser.downloader.github",
    })
  end)

  after_each(function()
    test_utils.restore_all({
      module_name,
      "theme-browser",
      "theme-browser.adapters.registry",
      "theme-browser.persistence.state",
      "theme-browser.application.theme_service",
      "theme-browser.package_manager.manager",
      "theme-browser.downloader.github",
    })
  end)

  describe("report generation", function()
    it("produces a report by iterating registry entries", function()
      local entries = {
        { id = "a", name = "theme-a", repo = "owner/a" },
        { id = "b", name = "theme-b", variant = "theme-b-dark", repo = "owner/b" },
      }

      setup_mocks(entries)
      vim.g.colors_name = "theme-a"

      local output_path = vim.fn.tempname() .. ".json"
      soak = require(module_name)
      local report = soak.run({ output_path = output_path })

      assert.is_true(report.ok)
      assert.equals(2, report.total_entries)
      assert.equals(2, report.ok_count)
      assert.equals(0, report.fail_count)
      assert.is_true(vim.fn.filereadable(output_path) == 1)
    end)

    it("validates colorscheme actually changes after apply", function()
      setup_mocks({ { id = "a", name = "theme-a", repo = "owner/a" } })
      vim.g.colors_name = "theme-a"

      soak = require(module_name)
      local report = soak.run({})

      assert.is_true(report.ok)
      assert.equals(1, report.ok_count)
      assert.is_true(report.items[1].colorscheme_ok)
    end)

    it("reports failure when colorscheme does not match expected", function()
      setup_mocks({ { id = "a", name = "theme-a", repo = "owner/a" } }, { set_colorscheme = false })
      vim.g.colors_name = "wrong-theme"

      soak = require(module_name)
      local report = soak.run({})

      assert.is_false(report.ok)
      assert.equals(0, report.ok_count)
      assert.equals(1, report.fail_count)
      assert.is_false(report.items[1].colorscheme_ok)
    end)

    it("reports failure when installation fails", function()
      setup_mocks(
        { { id = "a", name = "theme-a", repo = "owner/a" } },
        { installed = false, cached = false, install_success = false, download_fail = true }
      )

      soak = require(module_name)
      local report = soak.run({ timeout_ms = 1000 })

      assert.is_false(report.ok)
      assert.equals(0, report.ok_count)
      assert.equals(1, report.fail_count)
      assert.is_false(report.items[1].installed)
      assert.is_false(report.items[1].ok)
    end)
  end)

  describe("timeout handling", function()
    it("supports configurable timeout via opts", function()
      setup_mocks({})

      soak = require(module_name)
      local report = soak.run({ timeout_ms = 600000 })

      assert.is_true(report.ok)
    end)
  end)

  describe("progress callbacks", function()
    it("calls progress callback during validation", function()
      setup_mocks({ { id = "a", name = "theme-a", repo = "owner/a" } })
      vim.g.colors_name = "theme-a"

      local progress_calls = {}
      soak = require(module_name)
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
  end)

  describe("checkpoint save/resume", function()
    local function mock_time()
      return math.floor(vim.loop.hrtime() / 1e6)
    end

    it("saves and resumes from checkpoint", function()
      setup_mocks({
        { id = "a", name = "theme-a", repo = "owner/a" },
        { id = "b", name = "theme-b", repo = "owner/b" },
        { id = "c", name = "theme-c", repo = "owner/c" },
      })

      local checkpoint_path = vim.fn.tempname() .. "-checkpoint.json"
      vim.g.colors_name = "theme-a"

      soak = require(module_name)
      local report1 = soak.run({ checkpoint_path = checkpoint_path })

      assert.is_true(report1.ok)
      assert.is_false(report1.resumed_from_checkpoint)
      assert.equals(3, report1.total_entries)
      assert.equals(3, report1.ok_count)

      local file = io.open(checkpoint_path, "w")
      file:write(vim.json.encode({
        last_index = 1,
        items = { { name = "theme-a", ok = true } },
        started_at_ms = mock_time(),
      }))
      file:close()

      local report2 = soak.run({ checkpoint_path = checkpoint_path })

      assert.is_true(report2.resumed_from_checkpoint)
      assert.equals(1, report2.start_index)
    end)
  end)
end)
