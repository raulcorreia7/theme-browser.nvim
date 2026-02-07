local M = {}
local theme_service = require("theme-browser.application.theme_service")

local active_previews = {}
local preview_rtp_paths = {}

local function add_preview_record(theme_name, variant)
  active_previews[theme_name] = {
    bufnr = vim.api.nvim_get_current_buf(),
    winnr = vim.api.nvim_get_current_win(),
    variant = variant,
  }
end

local function track_preview_runtimepath(path)
  if type(path) == "string" and path ~= "" then
    preview_rtp_paths[path] = true
  end
end

local function remove_preview_rtp_paths()
  for path, _ in pairs(preview_rtp_paths) do
    pcall(function()
      vim.opt.runtimepath:remove(path)
    end)
  end
  preview_rtp_paths = {}
end

---Create preview without persisting selection.
---@param theme_name string
---@param variant string|nil
---@return number
function M.create_preview(theme_name, variant)
  return theme_service.preview(theme_name, variant, {
    notify = true,
    on_preview_applied = add_preview_record,
    on_runtimepath_added = track_preview_runtimepath,
  })
end

---@param theme_name string
function M.close_preview(theme_name)
  active_previews[theme_name] = nil
end

function M.cleanup()
  active_previews = {}
  remove_preview_rtp_paths()
end

function M.register_applied_preview(theme_name, variant)
  add_preview_record(theme_name, variant)
end

function M.track_runtimepath(path)
  track_preview_runtimepath(path)
end

---@return table
function M.list_previews()
  local result = {}
  for name, preview in pairs(active_previews) do
    table.insert(result, {
      name = name,
      bufnr = preview.bufnr,
      winnr = preview.winnr,
      variant = preview.variant,
    })
  end
  return result
end

return M
