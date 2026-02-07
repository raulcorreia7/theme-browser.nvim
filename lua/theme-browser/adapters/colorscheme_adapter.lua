local M = {
  adapter_type = "colorscheme",
}

function M.setup(opts)
  opts = opts or {}
  return opts
end

function M.load(theme_name, variant)
  local base = require("theme-browser.adapters.base")
  base.load_theme(theme_name, variant)
end

function M.preview(theme_name)
  local base = require("theme-browser.adapters.base")
  base.load_theme(theme_name, nil)
end

function M.get_status(theme_name)
  local base = require("theme-browser.adapters.base")
  return base.get_status(theme_name)
end

return M
