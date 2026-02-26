local M = {}

function M.pick(opts)
  local native = require("theme-browser.picker.native")
  return native.pick(opts)
end

return M
