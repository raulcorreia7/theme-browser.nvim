local M = {}

function M.pick(opts)
  local native = require("theme-browser.picker.native")
  return native.pick(opts)
end

function M.focus()
  local native = require("theme-browser.picker.native")
  if type(native.focus) ~= "function" then
    return false
  end
  return native.focus()
end

return M
