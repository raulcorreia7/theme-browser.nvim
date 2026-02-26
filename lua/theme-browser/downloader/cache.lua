local M = {}

local has_plenary_path, _ = pcall(require, "plenary.path")

local cache_meta = vim.fn.stdpath("cache") .. "/theme-browser/meta.json"
local cache_dir = has_plenary_path and require("plenary.path"):new(cache_meta):parent().filename
  or vim.fn.fnamemodify(cache_meta, ":h")
local state = require("theme-browser.persistence.state")
local update_meta
local cleanup_defaults = {
  auto_cleanup = true,
  cleanup_interval_days = 7,
}

local function read_cache_config()
  local ok, theme_browser = pcall(require, "theme-browser")
  if not ok or type(theme_browser.get_config) ~= "function" then
    return vim.deepcopy(cleanup_defaults)
  end

  local config = theme_browser.get_config()
  local cache_cfg = type(config) == "table" and config.cache or nil
  if type(cache_cfg) ~= "table" then
    return vim.deepcopy(cleanup_defaults)
  end

  local auto_cleanup = cache_cfg.auto_cleanup
  if auto_cleanup == nil then
    auto_cleanup = cleanup_defaults.auto_cleanup
  end

  local interval_days = tonumber(cache_cfg.cleanup_interval_days) or cleanup_defaults.cleanup_interval_days
  if interval_days < 1 then
    interval_days = 1
  end

  return {
    auto_cleanup = auto_cleanup == true,
    cleanup_interval_days = interval_days,
  }
end

---Clear all cache
---@param opts table|nil {notify:boolean|nil}
function M.clear_all(opts)
  opts = opts or {}
  local notify_enabled = opts.notify
  if notify_enabled == nil then
    notify_enabled = true
  end

  local config = require("theme-browser").get_config()
  local ok, result = pcall(vim.fn.delete, config.cache_dir, "rf")

  if ok and result == 0 then
    if notify_enabled then
      vim.notify("Theme cache cleared", vim.log.levels.INFO, { title = "Theme Browser" })
    end
    update_meta({})
    return true
  else
    local err = ok and string.format("delete returned %s", tostring(result)) or tostring(result)
    if notify_enabled then
      vim.notify(
        string.format("Failed to clear cache: %s", err),
        vim.log.levels.ERROR,
        { title = "Theme Browser" }
      )
    end
    return false, err
  end
end

---Get cache statistics
---@return table {hits, misses}
function M.get_stats()
  return state.get_cache_stats()
end

---Update cache metadata
---@param meta table Metadata to store
update_meta = function(meta)
  if vim.fn.isdirectory(cache_dir) == 0 then
    vim.fn.mkdir(cache_dir, "p")
  end

  local file = io.open(cache_meta, "w")
  if file then
    file:write(vim.json.encode(meta))
    file:close()
  end
end

---Load cache metadata
---@return table|nil
local function load_meta()
  if vim.fn.filereadable(cache_meta) == 0 then
    return {}
  end

  local content = table.concat(vim.fn.readfile(cache_meta), "\n")
  local ok, decoded = pcall(vim.json.decode, content)

  if ok then
    return decoded
  end

  return {}
end

---@param opts table|nil {notify:boolean|nil, force:boolean|nil}
---@return boolean cleaned, string|nil reason
function M.maybe_cleanup(opts)
  opts = opts or {}
  local force = opts.force == true
  local notify_enabled = opts.notify == true
  local policy = read_cache_config()

  if (not force) and not policy.auto_cleanup then
    return false, "disabled"
  end

  local now = os.time()
  local meta = load_meta()
  local last_cleanup_at = tonumber(meta.last_cleanup_at) or 0
  local interval_seconds = policy.cleanup_interval_days * 24 * 60 * 60

  if (not force) and last_cleanup_at > 0 and (now - last_cleanup_at) < interval_seconds then
    return false, "not_due"
  end

  local ok, err = M.clear_all({ notify = false })
  local next_meta = load_meta()
  next_meta.last_cleanup_at = now
  next_meta.last_cleanup_ok = ok == true
  if ok then
    next_meta.last_cleanup_error = nil
  else
    next_meta.last_cleanup_error = err
  end
  update_meta(next_meta)

  if notify_enabled then
    if ok then
      vim.notify("Theme cache weekly cleanup complete", vim.log.levels.INFO, { title = "Theme Browser" })
    else
      vim.notify(
        string.format("Theme cache cleanup failed: %s", err or "unknown error"),
        vim.log.levels.WARN,
        {
          title = "Theme Browser",
        }
      )
    end
  end

  return ok, err
end

---Increment cache hit
function M.record_hit()
  state.increment_cache_hit()
end

function M.record_miss()
  state.increment_cache_miss()
end

---Increment cache miss
function M.record_miss()
  local state = require("theme-browser.persistence.state")
  state.increment_cache_miss()
end

return M
