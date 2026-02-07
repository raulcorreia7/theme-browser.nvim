local M = {
  adapter_type = "setup",
}

local variants = { "light", "dark" }

function M.setup(opts)
  opts = opts or {}

  if opts.background then
    if opts.background == "light" or opts.background == "light_high_contrast" then
      opts.background = "light"
    else
      opts.background = "dark"
    end
  end

  return opts
end

function M.load(theme_name, variant)
  local setup_adapter = require("theme-browser.adapters.setup_adapter")
  local valid_variant = variant or "dark"

  if not vim.list_contains(variants, valid_variant) then
    vim.notify(
      string.format("Invalid variant '%s' for Everforest. Valid: light, dark", valid_variant),
      vim.log.levels.WARN
    )
    return
  end

  local config = {
    background = valid_variant,
  }

  setup_adapter.setup(config)
  setup_adapter.load(theme_name, nil)
end

function M.preview(theme_name)
  M.load(theme_name, "dark")
end

function M.get_status(theme_name)
  local setup_adapter = require("theme-browser.adapters.setup_adapter")
  local base_status = setup_adapter.get_status(theme_name)
  base_status.variants = variants
  return base_status
end

return M
