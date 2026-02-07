local M = {}

local preview_buffer = nil

---Preview theme in buffer
---@param theme_name string Theme name
function M.preview(theme_name)
  local registry = require("theme-browser.adapters.registry")
  local theme = registry.get_theme(theme_name)

  if not theme then
    vim.notify(string.format("Theme '%s' not found", theme_name), vim.log.levels.WARN)
    return
  end

  M.create_preview_buffer(theme)
  M.load_preview_content(theme)
end

---Create preview buffer
local function create_preview_buffer(theme)
  M.cleanup()

  preview_buffer = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(preview_buffer, string.format("Theme Preview: %s", theme.name))
  vim.api.nvim_buf_set_option(preview_buffer, "buftype", "nofile")
  vim.api.nvim_buf_set_option(preview_buffer, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(preview_buffer, "swapfile", false)

  vim.api.nvim_open_win(preview_buffer, true, {
    split = "right",
    win = 0,
  })
end

---Load preview content with sample code
local function load_preview_content(theme)
  local content = M.generate_sample_content()

  vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, content)

  local factory = require("theme-browser.adapters.factory")
  local ok, err = pcall(factory.preview_theme, theme.name)

  if not ok then
    vim.api.nvim_buf_set_lines(preview_buffer, 0, 1, false, {
      string.format("Failed to preview theme '%s': %s", theme.name, err or "unknown error"),
      "",
      "Press any key to try another theme...",
    })
    return
  end
end

---Generate sample code for preview
---@return string[]
function M.generate_sample_content()
  return {
    "",
    "-- Theme Preview Sample",
    "",
    "local M = {}",
    "",
    "function M.setup(opts)",
    "  opts = opts or {}",
    "  return opts",
    "end",
    "",
    "function M.load(theme_name)",
    "  vim.cmd.colorscheme(theme_name)",
    "end",
    "",
    "return M",
    "",
    "-- Example usage:",
    "-- local mytheme = require('mytheme')",
    "-- mytheme.setup({",
    "--   variant = 'dark',",
    "--   transparent = true",
    "-- })",
    "-- mytheme.load('mytheme')",
  }
end

---Clean up preview buffer
function M.cleanup()
  if preview_buffer and vim.api.nvim_buf_is_valid(preview_buffer) then
    local wins = vim.api.nvim_list_wins()

    for _, win in ipairs(wins) do
      if vim.api.nvim_win_get_buf(win) == preview_buffer then
        vim.api.nvim_win_close(win, true)
      end
    end

    vim.api.nvim_buf_delete(preview_buffer, { force = true })
  end

  preview_buffer = nil
end

return M
