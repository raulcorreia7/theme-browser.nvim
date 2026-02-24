local M = {}

local function now_ms()
  return math.floor(vim.loop.hrtime() / 1e6)
end

local function ensure_parent_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

local function default_output_path()
  return vim.fn.stdpath("state") .. "/theme-browser/validation-report.json"
end

local function wait_for_download(cache_dir, repo)
  local ok_dl, github = pcall(require, "theme-browser.downloader.github")
  if not ok_dl or type(github.download) ~= "function" then
    return false, "downloader unavailable"
  end

  local done = false
  local success = false
  local err_msg = nil

  github.download(repo, cache_dir, function(ok, err)
    done = true
    success = ok == true
    err_msg = err
  end, { notify = false })

  local waited = vim.wait(120000, function()
    return done
  end, 50)

  if not waited then
    return false, "download timeout"
  end

  if not success then
    return false, err_msg or "download failed"
  end

  return true, nil
end

local function ensure_installed(entry, config)
  local ok_pm, package_manager = pcall(require, "theme-browser.package_manager.manager")
  if ok_pm and type(package_manager.install_theme) == "function" then
    local ok_install, started = pcall(package_manager.install_theme, entry.name, entry.variant, {
      load = false,
      force = false,
      wait = true,
    })
    if ok_install and started == true then
      return true, nil
    end
  end

  if type(entry.repo) ~= "string" or entry.repo == "" then
    return false, "missing repo"
  end

  return wait_for_download(config.cache_dir, entry.repo)
end

function M.run(opts)
  opts = opts or {}

  local ok_tb, tb = pcall(require, "theme-browser")
  if not ok_tb or type(tb.get_config) ~= "function" then
    return { ok = false, error = "theme-browser config unavailable" }
  end

  local config = tb.get_config() or {}
  local output_path = opts.output_path or default_output_path()

  local registry = require("theme-browser.adapters.registry")
  local state = require("theme-browser.persistence.state")
  local service = require("theme-browser.application.theme_service")

  local entries = registry.list_entries()
  
  -- Filter to max 50 entries if sample requested
  if opts.sample_size and opts.sample_size > 0 then
    local limited = {}
    for i = 1, math.min(opts.sample_size, #entries) do
      table.insert(limited, entries[i])
    end
    entries = limited
  end
  
  local report = {
    started_at_ms = now_ms(),
    output_path = output_path,
    total_entries = #entries,
    ok_count = 0,
    fail_count = 0,
    notify_count = 0,
    failures = {},
    items = {},
    adapter_stats = {
      colorscheme_only = { count = 0, ok = 0, fail = 0 },
      setup_colorscheme = { count = 0, ok = 0, fail = 0 },
      vimg_colorscheme = { count = 0, ok = 0, fail = 0 },
      setup_load = { count = 0, ok = 0, fail = 0 },
    },
    timing = {
      total_install_ms = 0,
      total_preview_ms = 0,
      total_use_ms = 0,
    }
  }

  local original_notify = vim.notify
  vim.notify = function(...)
    report.notify_count = report.notify_count + 1
    return original_notify(...)
  end

  local function restore_notify()
    vim.notify = original_notify
  end

  local ok_run, run_err = xpcall(function()
    for _, entry in ipairs(entries) do
      local item = {
        id = entry.id,
        name = entry.name,
        variant = entry.variant,
        repo = entry.repo,
        colorscheme = entry.colorscheme,
        adapter_type = (entry.meta and entry.meta.strategy) or "colorscheme_only",
        installed = false,
        preview_ok = false,
        use_ok = false,
        ok = false,
        errors = {},
        timing = {},
      }

      -- Track adapter type stats
      local adapter_type = item.adapter_type
      if report.adapter_stats[adapter_type] then
        report.adapter_stats[adapter_type].count = report.adapter_stats[adapter_type].count + 1
      end

      -- Install timing
      local install_start = now_ms()
      local installed_ok, install_err = ensure_installed(entry, config)
      item.timing.install_ms = now_ms() - install_start
      report.timing.total_install_ms = report.timing.total_install_ms + item.timing.install_ms
      item.installed = installed_ok
      if not installed_ok and install_err then
        table.insert(item.errors, "install: " .. tostring(install_err))
      end

      -- Preview timing
      local preview_start = now_ms()
      local ok_preview, preview_err = pcall(service.preview, entry.name, entry.variant, {
        notify = false,
        install_missing = false,
        wait_install = false,
      })
      item.timing.preview_ms = now_ms() - preview_start
      report.timing.total_preview_ms = report.timing.total_preview_ms + item.timing.preview_ms
      item.preview_ok = ok_preview
      if not ok_preview then
        table.insert(item.errors, "preview: " .. tostring(preview_err))
      end

      -- Use timing
      local use_start = now_ms()
      local ok_use, use_err = pcall(service.use, entry.name, entry.variant, {
        notify = false,
        install_missing = false,
        wait_install = false,
      })
      item.timing.use_ms = now_ms() - use_start
      report.timing.total_use_ms = report.timing.total_use_ms + item.timing.use_ms
      item.use_ok = ok_use
      if not ok_use then
        table.insert(item.errors, "use: " .. tostring(use_err))
      end

      local current_state = state.get_entry_state(entry, { snapshot = state.build_state_snapshot() }) or {}
      item.cached = current_state.cached == true
      item.registry_installed = current_state.installed == true

      item.ok = item.installed and item.preview_ok and item.use_ok
      if item.ok then
        report.ok_count = report.ok_count + 1
        if report.adapter_stats[adapter_type] then
          report.adapter_stats[adapter_type].ok = report.adapter_stats[adapter_type].ok + 1
        end
      else
        report.fail_count = report.fail_count + 1
        if report.adapter_stats[adapter_type] then
          report.adapter_stats[adapter_type].fail = report.adapter_stats[adapter_type].fail + 1
        end
        table.insert(report.failures, {
          id = item.id,
          name = item.name,
          variant = item.variant,
          adapter_type = adapter_type,
          errors = item.errors,
          timing = item.timing,
        })
      end

      table.insert(report.items, item)
    end
  end, debug.traceback)

  restore_notify()

  if not ok_run then
    report.fail_count = report.fail_count + 1
    table.insert(report.failures, { name = "validator", errors = { tostring(run_err) } })
  end

  report.ended_at_ms = now_ms()
  report.duration_ms = report.ended_at_ms - report.started_at_ms
  report.ok = report.fail_count == 0 and report.notify_count == 0 and ok_run
  
  -- Calculate averages
  if #entries > 0 then
    report.timing.avg_install_ms = math.floor(report.timing.total_install_ms / #entries)
    report.timing.avg_preview_ms = math.floor(report.timing.total_preview_ms / #entries)
    report.timing.avg_use_ms = math.floor(report.timing.total_use_ms / #entries)
  end

  ensure_parent_dir(output_path)
  local file = io.open(output_path, "w")
  if file then
    file:write(vim.json.encode(report))
    file:close()
  end

  return report
end

return M
