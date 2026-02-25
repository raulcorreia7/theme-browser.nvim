local M = {}
local inflight = {}

local notify = require("theme-browser.util.notify")

local function queue_callback(repo, callback)
  if not inflight[repo] then
    inflight[repo] = {}
  end
  table.insert(inflight[repo], callback)
end

local function flush_callbacks(repo, success, message)
  local callbacks = inflight[repo] or {}
  inflight[repo] = nil
  for _, cb in ipairs(callbacks) do
    cb(success, message)
  end
end

local function ensure_cache_dir(cache_dir)
  if vim.fn.isdirectory(cache_dir) == 0 then
    vim.fn.mkdir(cache_dir, "p")
  end
end

local function has_git_credentials()
  local result = vim.fn.systemlist("git config --get credential.helper 2>/dev/null")
  if vim.v.shell_error == 0 and #result > 0 and result[1] ~= "" then
    return true
  end

  result = vim.fn.systemlist("gh auth status 2>&1")
  if vim.v.shell_error == 0 then
    return true
  end

  result = vim.fn.systemlist("git config --global user.name 2>/dev/null")
  if vim.v.shell_error == 0 and #result > 0 and result[1] ~= "" then
    return true
  end

  return false
end

local function sanitize_error_message(msg)
  if type(msg) ~= "string" then
    return "unknown error"
  end

  local sanitized = msg
  sanitized = sanitized:gsub("ghp_[%w]+", "ghp_***")
  sanitized = sanitized:gsub("gho_[%w]+", "gho_***")
  sanitized = sanitized:gsub("ghu_[%w]+", "ghu_***")
  sanitized = sanitized:gsub("ghs_[%w]+", "ghs_***")
  sanitized = sanitized:gsub("ghr_[%w]+", "ghr_***")
  sanitized = sanitized:gsub("github_pat_[%w]+", "github_pat_***")
  sanitized = sanitized:gsub("token=[%w%-_]+", "token=***")
  sanitized = sanitized:gsub("access_token=[%w%-_]+", "access_token=***")
  sanitized = sanitized:gsub("Authorization: token [%w%-_]+", "Authorization: token ***")
  
  return sanitized
end

M._sanitize_error_message = sanitize_error_message

function M.download(repo, cache_dir, callback, opts)
  opts = opts or {}
  local notify_enabled = opts.notify
  if notify_enabled == nil then
    notify_enabled = true
  end
  local title = opts.title or "Theme Browser"

  local owner, name = repo:match("([^/]+)/(.+)")

  if not owner or not name then
    callback(false, string.format("Invalid repo format: %s", repo))
    return
  end

  local cache_path = M.get_cache_path(repo, cache_dir)

  ensure_cache_dir(cache_dir)

  if M.is_cached(repo, cache_dir) then
    callback(true, nil)
    return
  end

  if inflight[repo] then
    queue_callback(repo, callback)
    return
  end
  queue_callback(repo, callback)

  local use_credentials = has_git_credentials()
  local clone_url
  if use_credentials then
    clone_url = string.format("https://github.com/%s/%s.git", owner, name)
  else
    clone_url = string.format("https://github.com/%s/%s.git", owner, name)
  end

  local clone_args = {
    "clone",
    "--depth=1",
    "--filter=blob:none",
    "--single-branch",
    "--no-tags",
  }

  if use_credentials then
    table.insert(clone_args, "--config")
    table.insert(clone_args, "credential.helper=cache --timeout=3600")
  end

  table.insert(clone_args, clone_url)
  table.insert(clone_args, cache_path)

  local has_plenary, _ = pcall(require, "plenary")

  if has_plenary then
    local plenary_job = require("plenary.job")
    local notify_id = nil
    if notify_enabled then
      notify_id = vim.notify(string.format("Downloading %s...", repo), vim.log.levels.INFO, { title = title })
    end

    local job = plenary_job:new({
      command = "git",
      args = clone_args,
      on_exit = function(j, code, signal)
        local _ = signal
        vim.schedule(function()
          if notify_id then
            pcall(vim.notify, "", vim.log.levels.INFO)
          end

          if code == 0 then
            local cache = require("theme-browser.downloader.cache")
            cache.record_hit()
            if notify_enabled then
              notify.info(string.format("Downloaded: %s", repo), { title = title, theme = repo })
            end
            flush_callbacks(repo, true, nil)
          else
            local cache = require("theme-browser.downloader.cache")
            cache.record_miss()
            local stderr = sanitize_error_message(table.concat(j:stderr_result(), "\n"))
            if notify_enabled then
              notify.error(string.format("Download failed (code %d): %s", code, stderr), { title = title, theme = repo })
            end
            flush_callbacks(repo, false, string.format("Download failed (code %d): %s", code, stderr))
          end
        end)
      end,
      on_stderr = function(_, data)
        if not notify_enabled or not notify_id then
          return
        end
        local progress_data = data:match("Receiving objects:? *(%d+)%%")
        if progress_data then
          pcall(vim.notify, string.format("Downloading: %s%%", progress_data), vim.log.levels.INFO, {
            title = title,
            replace = notify_id,
          })
        end
      end,
    })

    job:start()
  elseif vim.system then
    local notify_id = nil
    if notify_enabled then
      notify_id = vim.notify(string.format("Downloading %s...", repo), vim.log.levels.INFO, { title = title })
    end

    vim.system(vim.list_extend({ "git" }, clone_args), { text = true }, function(result)
      vim.schedule(function()
        if notify_id then
          pcall(vim.notify, "", vim.log.levels.INFO)
        end

        if result.code == 0 then
          local cache = require("theme-browser.downloader.cache")
          cache.record_hit()
          if notify_enabled then
            notify.info(string.format("Downloaded: %s", repo), { title = title, theme = repo })
          end
          flush_callbacks(repo, true, nil)
        else
          local cache = require("theme-browser.downloader.cache")
          cache.record_miss()
          local err = sanitize_error_message(result.stderr or result.stdout or "unknown error")
          if notify_enabled then
            notify.error(string.format("Download failed (code %d): %s", result.code, err), { title = title, theme = repo })
          end
          flush_callbacks(repo, false, string.format("Download failed (code %d): %s", result.code, err))
        end
      end)
    end)
  else
    local output = vim.fn.system(vim.list_extend({ "git" }, clone_args))

    if vim.v.shell_error ~= 0 then
      local cache = require("theme-browser.downloader.cache")
      cache.record_miss()
      flush_callbacks(repo, false, sanitize_error_message(output))
    else
      local cache = require("theme-browser.downloader.cache")
      cache.record_hit()
      flush_callbacks(repo, true, nil)
    end
  end
end

---Get cache path for theme
---@param repo string
---@param cache_dir string
---@return string
local function slug_repo(repo)
  if type(repo) ~= "string" then
    return "unknown"
  end
  return repo:gsub("/", "__"):gsub("[^%w%-%._]", "-")
end

local function legacy_repo_name(repo)
  local _, name = repo:match("([^/]+)/(.+)")
  return name
end

local function get_legacy_cache_path(repo, cache_dir)
  local legacy = legacy_repo_name(repo)
  if type(legacy) ~= "string" or legacy == "" then
    return nil
  end
  return cache_dir .. "/" .. legacy
end

function M.get_cache_path(repo, cache_dir)
  return cache_dir .. "/" .. slug_repo(repo)
end

function M.resolve_cache_path(repo, cache_dir)
  local path = M.get_cache_path(repo, cache_dir)
  if vim.fn.isdirectory(path) == 1 then
    return path
  end

  local legacy_path = get_legacy_cache_path(repo, cache_dir)
  if legacy_path and vim.fn.isdirectory(legacy_path) == 1 then
    return legacy_path
  end

  return path
end

---Check if theme is cached
---@param repo string
---@param cache_dir string
---@return boolean
function M.is_cached(repo, cache_dir)
  local path = M.get_cache_path(repo, cache_dir)
  if vim.fn.isdirectory(path) == 1 then
    return true
  end

  local legacy_path = get_legacy_cache_path(repo, cache_dir)
  if legacy_path then
    return vim.fn.isdirectory(legacy_path) == 1
  end

  return false
end

---Remove theme from cache
---@param repo string
---@param cache_dir string
---@return boolean success
function M.remove_cached(repo, cache_dir)
  local path = M.get_cache_path(repo, cache_dir)
  local legacy_path = get_legacy_cache_path(repo, cache_dir)

  local ok_main = true
  if vim.fn.isdirectory(path) == 1 then
    ok_main = vim.fn.delete(path, "rf") == 0
  end

  local ok_legacy = true
  if legacy_path and legacy_path ~= path and vim.fn.isdirectory(legacy_path) == 1 then
    ok_legacy = vim.fn.delete(legacy_path, "rf") == 0
  end

  return ok_main and ok_legacy
end

return M
