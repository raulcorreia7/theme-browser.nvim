local M = {
  adapter_type = "setup",
}

local variants = { "wave", "dragon", "lotus" }

function M.setup(opts)
  opts = opts or {}
  return opts
end

function M.load(theme_name, variant)
  local setup_adapter = require("theme-browser.adapters.setup_adapter")
  local valid_variant = variant or "wave"

  if not vim.list_contains(variants, valid_variant) then
    vim.notify(
      string.format("Invalid variant '%s' for Kanagawa. Valid: wave, dragon, lotus", valid_variant),
      vim.log.levels.WARN
    )
    return
  end

  local config = {
    theme = valid_variant,
  }

  setup_adapter.setup(config)
  setup_adapter.load(theme_name, valid_variant)
end

function M.preview(theme_name)
  M.load(theme_name, "wave")
end

function M.get_status(theme_name)
  local setup_adapter = require("theme-browser.adapters.setup_adapter")
  local base_status = setup_adapter.get_status(theme_name)
  base_status.variants = variants
  return base_status
end

return M
