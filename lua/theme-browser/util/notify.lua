local M = {}

local THROTTLE_MS = 200
local DEDUP_MS = 100

local last_notification = {}
local dedup_cache = {}

local function now_ms()
  return math.floor(vim.loop.hrtime() / 1000000)
end

local function make_key(level, message, opts)
  local theme = ""
  if type(opts) == "table" and type(opts.theme) == "string" then
    theme = opts.theme
  end
  return string.format("%d:%s:%s", level, theme, message)
end

local function is_throttled(key)
  local last = last_notification[key]
  if not last then
    return false
  end
  return (now_ms() - last) < THROTTLE_MS
end

local function is_duplicate(level, message)
  local hash = string.format("%d:%s", level, message)
  local seen = dedup_cache[hash]
  if not seen then
    return false
  end
  return (now_ms() - seen) < DEDUP_MS
end

local function record_notification(key, level, message)
  last_notification[key] = now_ms()
  local hash = string.format("%d:%s", level, message)
  dedup_cache[hash] = now_ms()
end

local function cleanup_old_entries()
  local cutoff = now_ms() - (THROTTLE_MS * 2)
  for k, v in pairs(last_notification) do
    if v < cutoff then
      last_notification[k] = nil
    end
  end
  for k, v in pairs(dedup_cache) do
    if v < cutoff then
      dedup_cache[k] = nil
    end
  end
end

vim.api.nvim_create_autocmd("User", {
  pattern = "ThemeBrowserNotifyCleanup",
  callback = cleanup_old_entries,
})

function M.notify(level, message, opts)
  opts = opts or {}

  if is_duplicate(level, message) then
    return
  end

  local key = make_key(level, message, opts)
  if is_throttled(key) then
    return
  end

  record_notification(key, level, message)

  local title = "Theme Browser"
  if type(opts.title) == "string" and opts.title ~= "" then
    title = opts.title
  end

  vim.notify(message, level, { title = title })
end

function M.info(message, opts)
  M.notify(vim.log.levels.INFO, message, opts)
end

function M.warn(message, opts)
  M.notify(vim.log.levels.WARN, message, opts)
end

function M.error(message, opts)
  M.notify(vim.log.levels.ERROR, message, opts)
end

return M
