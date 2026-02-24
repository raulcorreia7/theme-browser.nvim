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

local function default_checkpoint_path()
  return vim.fn.stdpath("state") .. "/theme-browser/validation-checkpoint.json"
end

local function load_checkpoint(checkpoint_path)
  if vim.fn.filereadable(checkpoint_path) ~= 1 then
    return nil
  end
  local ok, content = pcall(vim.fn.readfile, checkpoint_path)
  if not ok or not content or #content == 0 then
    return nil
  end
  local ok_decode, data = pcall(vim.json.decode, table.concat(content, "\n"))
  if ok_decode and data and data.last_index then
    return data
  end
  return nil
end

local function save_checkpoint(checkpoint_path, data)
  ensure_parent_dir(checkpoint_path)
  local file = io.open(checkpoint_path, "w")
  if file then
    file:write(vim.json.encode(data))
    file:close()
  end
end

local function clear_checkpoint(checkpoint_path)
  pcall(vim.fn.delete, checkpoint_path)
end

local function try_download_once(github, repo, cache_dir, timeout_ms)
  local done = false
  local success = false
  local err_msg = nil

  github.download(repo, cache_dir, function(ok, err)
    done = true
    success = ok == true
    err_msg = err
  end, { notify = false })

  local waited = vim.wait(timeout_ms, function()
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

local function wait_for_download(cache_dir, repo, timeout_ms)
  timeout_ms = timeout_ms or 300000
  local max_retries = 3
  local retry_delays = { 1000, 2000, 4000 }

  local ok_dl, github = pcall(require, "theme-browser.downloader.github")
  if not ok_dl or type(github.download) ~= "function" then
    return false, "downloader unavailable"
  end

  local last_error = nil

  for attempt = 1, max_retries do
    local ok, err = try_download_once(github, repo, cache_dir, timeout_ms)
    if ok then
      return true, nil
    end

    last_error = err

    if attempt < max_retries then
      vim.wait(retry_delays[attempt] or 4000)
    end
  end

  return false, last_error or "download failed after " .. max_retries .. " attempts"
end

local function ensure_installed(entry, config, timeout_ms)
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

  return wait_for_download(config.cache_dir, entry.repo, timeout_ms)
end

local function get_current_colorscheme()
  return vim.g.colors_name
end

local function validate_colorscheme_change(expected_name, expected_variant)
  local current = get_current_colorscheme()
  if not current then
    return false, "no colorscheme active"
  end

  local expected = expected_variant or expected_name
  if current ~= expected then
    return false, string.format("colorscheme mismatch: expected '%s', got '%s'", expected, current)
  end

  return true, nil
end

function M.run(opts)
  opts = opts or {}

  local ok_tb, tb = pcall(require, "theme-browser")
  if not ok_tb or type(tb.get_config) ~= "function" then
    return { ok = false, error = "theme-browser config unavailable" }
  end

  local config = tb.get_config() or {}
  local output_path = opts.output_path or default_output_path()
  local checkpoint_path = opts.checkpoint_path or default_checkpoint_path()
  local timeout_ms = opts.timeout_ms or 300000
  local on_progress = opts.on_progress

  local registry = require("theme-browser.adapters.registry")
  local state = require("theme-browser.persistence.state")
  local service = require("theme-browser.application.theme_service")

  local entries = registry.list_entries()
  local checkpoint = opts.resume ~= false and load_checkpoint(checkpoint_path) or nil
  local start_index = checkpoint and checkpoint.last_index or 0

  local report = {
    started_at_ms = now_ms(),
    output_path = output_path,
    checkpoint_path = checkpoint_path,
    total_entries = #entries,
    start_index = start_index,
    ok_count = 0,
    fail_count = 0,
    notify_count = 0,
    failures = {},
    items = checkpoint and checkpoint.items or {},
    resumed_from_checkpoint = checkpoint ~= nil,
  }

  local original_notify = vim.notify
  vim.notify = function(...)
    report.notify_count = report.notify_count + 1
    return original_notify(...)
  end

  local function restore_notify()
    vim.notify = original_notify
  end

  local function report_progress(done, total, current_name, status)
    if type(on_progress) == "function" then
      local ok, err = pcall(on_progress, done, total, current_name, status)
      if not ok then
        original_notify("progress callback error: " .. tostring(err), vim.log.levels.WARN)
      end
    end
  end

  local ok_run, run_err = xpcall(function()
    for i = start_index + 1, #entries do
      local entry = entries[i]
      local item = {
        id = entry.id,
        name = entry.name,
        variant = entry.variant,
        repo = entry.repo,
        installed = false,
        preview_ok = false,
        use_ok = false,
        colorscheme_ok = false,
        ok = false,
        errors = {},
      }

      report_progress(i - 1, #entries, entry.name, "installing")

      local installed_ok, install_err = ensure_installed(entry, config, timeout_ms)
      item.installed = installed_ok
      if not installed_ok and install_err then
        table.insert(item.errors, "install: " .. tostring(install_err))
      end

      report_progress(i - 1, #entries, entry.name, "previewing")

      local ok_preview, preview_err = pcall(service.preview, entry.name, entry.variant, {
        notify = false,
        install_missing = false,
        wait_install = false,
      })
      item.preview_ok = ok_preview
      if not ok_preview then
        table.insert(item.errors, "preview: " .. tostring(preview_err))
      end

      report_progress(i - 1, #entries, entry.name, "applying")

      local original_colorscheme = get_current_colorscheme()

      local ok_use, use_err = pcall(service.use, entry.name, entry.variant, {
        notify = false,
        install_missing = false,
        wait_install = false,
      })
      item.use_ok = ok_use
      if not ok_use then
        table.insert(item.errors, "use: " .. tostring(use_err))
      end

      local colorscheme_ok, colorscheme_err = validate_colorscheme_change(entry.name, entry.variant)
      item.colorscheme_ok = colorscheme_ok
      if not colorscheme_ok then
        table.insert(item.errors, "colorscheme: " .. tostring(colorscheme_err))
      end

      local current_state = state.get_entry_state(entry, { snapshot = state.build_state_snapshot() }) or {}
      item.cached = current_state.cached == true
      item.registry_installed = current_state.installed == true

      item.ok = item.installed and item.preview_ok and item.use_ok and item.colorscheme_ok
      if item.ok then
        report.ok_count = report.ok_count + 1
      else
        report.fail_count = report.fail_count + 1
        table.insert(report.failures, {
          id = item.id,
          name = item.name,
          variant = item.variant,
          errors = item.errors,
        })
      end

      table.insert(report.items, item)

      report_progress(i, #entries, entry.name, item.ok and "ok" or "failed")

      if i % 10 == 0 then
        save_checkpoint(checkpoint_path, {
          last_index = i,
          items = report.items,
          started_at_ms = report.started_at_ms,
        })
      end
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

  ensure_parent_dir(output_path)
  local file = io.open(output_path, "w")
  if file then
    file:write(vim.json.encode(report))
    file:close()
  end

  if report.ok then
    clear_checkpoint(checkpoint_path)
  end

  return report
end

return M
