local M = {}

local LEVELS = {
  error = vim.log.levels.ERROR,
  warn = vim.log.levels.WARN,
  info = vim.log.levels.INFO,
  debug = vim.log.levels.DEBUG,
}

local ORDER = {
  [vim.log.levels.ERROR] = 1,
  [vim.log.levels.WARN] = 2,
  [vim.log.levels.INFO] = 3,
  [vim.log.levels.DEBUG] = 4,
}

local function configured_level()
  local ok, theme_browser = pcall(require, "theme-browser")
  if not ok or type(theme_browser.get_config) ~= "function" then
    return vim.log.levels.INFO
  end

  local config = theme_browser.get_config()
  if type(config) ~= "table" or type(config.log_level) ~= "string" then
    return vim.log.levels.INFO
  end

  return LEVELS[config.log_level:lower()] or vim.log.levels.INFO
end

local function should_emit(level)
  return (ORDER[level] or 99) <= (ORDER[configured_level()] or 99)
end

---@param level integer
---@param message string
---@param opts table|nil
function M.notify(level, message, opts)
  if not should_emit(level) then
    return
  end

  local title = "Theme Browser"
  if type(opts) == "table" and type(opts.title) == "string" and opts.title ~= "" then
    title = opts.title
  end
  vim.notify(message, level, { title = title })
end

function M.error(message, opts)
  M.notify(vim.log.levels.ERROR, message, opts)
end

function M.warn(message, opts)
  M.notify(vim.log.levels.WARN, message, opts)
end

function M.info(message, opts)
  M.notify(vim.log.levels.INFO, message, opts)
end

function M.debug(message, opts)
  M.notify(vim.log.levels.DEBUG, message, opts)
end

return M
