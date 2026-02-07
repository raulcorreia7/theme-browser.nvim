local M = {
  adapter_type = "setup",
}

local config = {}

function M.setup(opts)
  opts = opts or {}
  config = opts
  return opts
end

function M.load(theme_name, variant)
  local base = require("theme-browser.adapters.base")

  if base.has_package_manager() then
    local state = require("theme-browser.persistence.state")
    state.set_current_theme(theme_name, variant)
    vim.notify(
      string.format("Theme '%s' selected (delegating to package manager)", theme_name),
      vim.log.levels.INFO,
      { title = "🎨 Theme Browser" }
    )
  else
    local actual_colorscheme = variant and theme_name .. "-" .. variant or theme_name
    local success, err = pcall(function()
      if variant then
        vim.cmd.colorscheme(actual_colorscheme)
      else
        vim.cmd.colorscheme(theme_name)
      end
    end)

    if success then
      local state = require("theme-browser.persistence.state")
      state.set_current_theme(theme_name, variant)
      vim.notify(
        string.format("Theme '%s' loaded successfully", theme_name),
        vim.log.levels.INFO,
        { title = "🎨 Theme Browser" }
      )
    else
      vim.notify(
        string.format("Failed to load theme '%s': %s", theme_name, err),
        vim.log.levels.ERROR,
        { title = "🎨 Theme Browser" }
      )
    end
  end
end

function M.preview(theme_name)
  M.load(theme_name)
end

function M.get_config()
  return config
end

function M.get_status(theme_name)
  local base = require("theme-browser.adapters.base")
  return base.get_status(theme_name)
end

return M
