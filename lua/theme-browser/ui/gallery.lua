local M = {}

local has_nui_popup, NuiPopup = pcall(require, "nui.popup")

local gallery_popup = nil
local gallery_winid = nil
local gallery_bufnr = nil
local is_open = false
local ns = vim.api.nvim_create_namespace("theme-browser-gallery")

local all_entries = {}
local filtered_entries = {}
local selected_idx = 1
local current_query = ""
local is_rendering = false
local log = require("theme-browser.util.log")
local row_offset = 0
local search_context_active = false
local render
local navigate_to

local function index_to_row(index)
  return index + row_offset
end

local function row_to_index(row)
  return row - row_offset
end

local function get_config()
  return require("theme-browser").get_config()
end

local function get_window_size()
  local config = get_config()
  local width = math.floor(vim.o.columns * (config.ui.window_width or 0.6))
  local height = math.floor(vim.o.lines * (config.ui.window_height or 0.5))
  width = math.max(56, math.min(width, 92))
  height = math.max(12, math.min(height, 22))
  return width, height
end

local function create_gallery_window()
  local config = get_config()
  local width, height = get_window_size()

  if has_nui_popup then
    gallery_popup = NuiPopup({
      enter = true,
      position = "50%",
      size = {
        width = width,
        height = height,
      },
      border = {
        style = config.ui.border or "rounded",
        text = {
          top = " Theme Browser ",
          top_align = "center",
        },
      },
      win_options = {
        winhighlight = "Normal:Normal,FloatBorder:Normal",
        cursorline = true,
      },
    })

    gallery_popup:mount()
    gallery_bufnr = gallery_popup.bufnr
    gallery_winid = gallery_popup.winid
  else
    gallery_bufnr = vim.api.nvim_create_buf(false, true)
    gallery_winid = vim.api.nvim_open_win(gallery_bufnr, true, {
      relative = "editor",
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      width = width,
      height = height,
      style = "minimal",
      border = config.ui.border or "rounded",
      title = " Theme Browser ",
      title_pos = "center",
    })

    vim.api.nvim_set_option_value("winhighlight", "Normal:Normal,FloatBorder:Normal", { win = gallery_winid })
    vim.api.nvim_set_option_value("cursorline", true, { win = gallery_winid })
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = gallery_bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = gallery_bufnr })
  vim.api.nvim_set_option_value("filetype", "theme-browser-gallery", { buf = gallery_bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = gallery_bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = gallery_bufnr })

  is_open = true
end

local function focus_gallery_window()
  if gallery_winid and vim.api.nvim_win_is_valid(gallery_winid) then
    local ok = pcall(vim.api.nvim_set_current_win, gallery_winid)
    return ok
  end
  return false
end

local function format_state_column(state, entry, snapshot)
  if type(state.get_entry_state) ~= "function" then
    if type(state.format_entry_states) == "function" then
      return state.format_entry_states(entry, { all = false, pretty = false })
    end
    return "Available"
  end

  local entry_state = state.get_entry_state(entry, { snapshot = snapshot })
  local labels = {}

  if entry_state.active then
    table.insert(labels, "Current")
  end
  if entry_state.installed then
    table.insert(labels, "Installed")
  end
  if entry_state.cached then
    table.insert(labels, "Downloaded")
  end
  if entry_state.marked then
    table.insert(labels, "Marked")
  end

  if #labels == 0 then
    return "Available"
  end

  return table.concat(labels, ", ")
end

local function sync_selection_to_cursor(opts)
  opts = opts or {}
  if not gallery_winid or not vim.api.nvim_win_is_valid(gallery_winid) then
    return false
  end

  if #filtered_entries == 0 then
    selected_idx = 1
    return false
  end

  local row = vim.api.nvim_win_get_cursor(gallery_winid)[1]
  local first_row = index_to_row(1)
  local last_row = index_to_row(#filtered_entries)
  local changed = false

  if opts.clamp == true and (row < first_row or row > last_row) then
    row = math.max(first_row, math.min(last_row, row))
    pcall(vim.api.nvim_win_set_cursor, gallery_winid, { row, 0 })
    changed = true
  end

  local line = row_to_index(row)
  if line >= 1 and line <= #filtered_entries and line ~= selected_idx then
    selected_idx = line
    changed = true
  end

  if changed then
    render()
  end

  return changed
end

local function clear_search_context()
  if vim.v.hlsearch == 1 then
    vim.cmd("nohlsearch")
  end
  vim.fn.setreg("/", "")
  search_context_active = false
end

local function filter_entries()
  if current_query == "" then
    filtered_entries = all_entries
    return
  end

  local query = current_query:lower()
  filtered_entries = {}

  for _, entry in ipairs(all_entries) do
    local variant = entry.variant or "default"
    local id = string.format("%s:%s", entry.name, variant)

    if entry.name:lower():find(query, 1, true)
      or variant:lower():find(query, 1, true)
      or (entry.repo and entry.repo:lower():find(query, 1, true))
      or id:lower():find(query, 1, true)
    then
      table.insert(filtered_entries, entry)
    end
  end
end

local function get_selected_entry()
  if gallery_winid and vim.api.nvim_win_is_valid(gallery_winid) then
    local cursor = vim.api.nvim_win_get_cursor(gallery_winid)
    local line = row_to_index(cursor[1])
    if line >= 1 and line <= #filtered_entries then
      selected_idx = line
    end
  end

  if selected_idx < 1 or selected_idx > #filtered_entries then
    return nil
  end
  return filtered_entries[selected_idx]
end

local function set_cursor_to_selected()
  if not gallery_winid or not vim.api.nvim_win_is_valid(gallery_winid) then
    return
  end

  local line = selected_idx
  if line < 1 then
    line = 1
  end
  vim.api.nvim_win_set_cursor(gallery_winid, { index_to_row(line), 0 })
end

render = function()
  if not gallery_bufnr or not vim.api.nvim_buf_is_valid(gallery_bufnr) then
    return
  end

  is_rendering = true

  local state = require("theme-browser.persistence.state")
  local lines = {}
  local snapshot = type(state.build_state_snapshot) == "function" and state.build_state_snapshot() or nil

  local left_width = 24
  for _, entry in ipairs(filtered_entries) do
    local variant = entry.variant or "default"
    local label = string.format("%s - %s", entry.name, variant)
    if #label > left_width then
      left_width = #label
    end
  end
  left_width = math.min(left_width + 2, 56)

  local function fit(text, width)
    if #text <= width then
      return text .. string.rep(" ", width - #text)
    end
    if width <= 1 then
      return text:sub(1, width)
    end
    return text:sub(1, width - 1) .. "~"
  end

  if #filtered_entries == 0 then
    row_offset = 0
    table.insert(lines, "No themes found")
    selected_idx = 1
  else
    row_offset = 3
    table.insert(lines, fit("Theme - Variant", left_width) .. " State")
    table.insert(lines, "[/] search  [n/N] next/prev  [Enter] apply  [p] preview  [i] install  [m] mark  [Esc] back")
    table.insert(lines, string.rep("-", left_width) .. " -----")
    for _, entry in ipairs(filtered_entries) do
      local variant = entry.variant or "default"
      local states = format_state_column(state, entry, snapshot)
      local label = fit(string.format("%s - %s", entry.name, variant), left_width)
      table.insert(lines, string.format("%s %s", label, states))
    end
  end

  table.insert(lines, "")
  table.insert(lines, "j/k, C-n/C-p, C-j/C-k move  gg/G bounds  / search  n/N next/prev")
  table.insert(lines, "<CR> apply  p preview  i install  m mark  q close")
  table.insert(lines, "<Esc>: clear search first, close when no search is active")
  table.insert(lines, "ThemeBrowserFocus re-focuses gallery if window focus is lost")
  table.insert(lines, "states: Current, Installed, Downloaded, Marked")

  vim.api.nvim_set_option_value("modifiable", true, { buf = gallery_bufnr })
  vim.api.nvim_buf_set_lines(gallery_bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(gallery_bufnr, ns, 0, -1)
  if #filtered_entries > 0 and selected_idx >= 1 and selected_idx <= #filtered_entries then
    vim.api.nvim_buf_set_extmark(gallery_bufnr, ns, index_to_row(selected_idx) - 1, 0, {
      line_hl_group = "PmenuSel",
      priority = 100,
    })
  end
  vim.api.nvim_set_option_value("modifiable", false, { buf = gallery_bufnr })

  if #filtered_entries > 0 then
    set_cursor_to_selected()
  end

  is_rendering = false
end

navigate_to = function(idx)
  if #filtered_entries == 0 then
    selected_idx = 1
    return
  end

  if idx < 1 then
    idx = 1
  elseif idx > #filtered_entries then
    idx = #filtered_entries
  end

  selected_idx = idx
  render()
end

local function apply_selected()
  local entry = get_selected_entry()
  if not entry then
    return
  end

  local theme_service = require("theme-browser.application.theme_service")
  theme_service.apply(entry.name, entry.variant)
  render()
  focus_gallery_window()
end

local function preview_selected()
  local entry = get_selected_entry()
  if not entry then
    return
  end

  local theme_service = require("theme-browser.application.theme_service")
  theme_service.preview(entry.name, entry.variant)
  render()
  focus_gallery_window()
end

local function install_selected()
  local entry = get_selected_entry()
  if not entry then
    return
  end

  local theme_service = require("theme-browser.application.theme_service")
  theme_service.install(entry.name, entry.variant)
  render()
  focus_gallery_window()
end

local function mark_selected()
  local entry = get_selected_entry()
  if not entry then
    return
  end

  local state = require("theme-browser.persistence.state")
  state.mark_theme(entry.name, entry.variant)
  render()
  focus_gallery_window()
end

function M.apply_current()
  apply_selected()
end

function M.preview_current()
  preview_selected()
end

function M.install_current()
  install_selected()
end

function M.mark_current()
  mark_selected()
end

local function setup_keymaps()
  local opts = { buffer = gallery_bufnr, nowait = true, silent = true }
  local keymaps = get_config().keymaps or {}

  local function map_keys(keys, fn)
    if type(keys) ~= "table" then
      return
    end
    for _, lhs in ipairs(keys) do
      vim.keymap.set("n", lhs, fn, opts)
    end
  end

  map_keys(keymaps.navigate_down or { "j" }, function()
    navigate_to(selected_idx + 1)
  end)

  vim.keymap.set("n", "<C-j>", function()
    navigate_to(selected_idx + 1)
  end, opts)

  vim.keymap.set("n", "<Down>", function()
    navigate_to(selected_idx + 1)
  end, opts)

  vim.keymap.set("n", "<C-n>", function()
    navigate_to(selected_idx + 1)
  end, opts)

  map_keys(keymaps.navigate_up or { "k" }, function()
    navigate_to(selected_idx - 1)
  end)

  vim.keymap.set("n", "<C-k>", function()
    navigate_to(selected_idx - 1)
  end, opts)

  vim.keymap.set("n", "<Up>", function()
    navigate_to(selected_idx - 1)
  end, opts)

  vim.keymap.set("n", "<C-p>", function()
    navigate_to(selected_idx - 1)
  end, opts)

  map_keys(keymaps.goto_top or { "gg" }, function()
    navigate_to(1)
  end)

  map_keys(keymaps.goto_bottom or { "G" }, function()
    navigate_to(#filtered_entries)
  end)

  map_keys(keymaps.select or { "<CR>" }, apply_selected)
  map_keys(keymaps.preview or { "p" }, preview_selected)
  map_keys(keymaps.install or { "i" }, install_selected)
  map_keys(keymaps.mark or { "m" }, mark_selected)

  vim.keymap.set("n", "n", function()
    if vim.fn.getreg("/") ~= "" then
      search_context_active = true
    end
    local ok = pcall(vim.cmd, "normal! n")
    if not ok then
      return
    end
    sync_selection_to_cursor({ clamp = true })
  end, opts)

  vim.keymap.set("n", "N", function()
    if vim.fn.getreg("/") ~= "" then
      search_context_active = true
    end
    local ok = pcall(vim.cmd, "normal! N")
    if not ok then
      return
    end
    sync_selection_to_cursor({ clamp = true })
  end, opts)

  map_keys(keymaps.close or { "<Esc>" }, function()
    if search_context_active or vim.v.hlsearch == 1 or vim.fn.getreg("/") ~= "" then
      clear_search_context()
      return
    end
    M.close()
  end)

  vim.keymap.set("n", "<C-h>", focus_gallery_window, opts)
  vim.keymap.set("n", "<C-l>", focus_gallery_window, opts)

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = gallery_bufnr,
    callback = function()
      if is_rendering then
        return
      end
      if not gallery_winid or not vim.api.nvim_win_is_valid(gallery_winid) then
        return
      end
      sync_selection_to_cursor({ clamp = false })
    end,
  })
end

---@param query string|nil
function M.open(query)
  if is_open then
    if focus_gallery_window() then
      return
    end
    M.close()
  end

  local registry = require("theme-browser.adapters.registry")
  if type(registry.is_initialized) == "function" and not registry.is_initialized() then
    local config = get_config()
    registry.initialize(config.registry_path)
  end
  all_entries = registry.list_entries()
  if #all_entries == 0 then
    log.warn("Theme registry is empty or not loaded")
  end
  current_query = query or ""
  search_context_active = false

  filter_entries()
  selected_idx = 1

  local current = require("theme-browser.persistence.state").get_current_theme()
  if current then
    for idx, entry in ipairs(filtered_entries) do
      if entry.name == current.name and (entry.variant or "") == (current.variant or "") then
        selected_idx = idx
        break
      end
    end
  end

  create_gallery_window()
  focus_gallery_window()
  setup_keymaps()
  render()
  focus_gallery_window()
end

function M.focus()
  if not is_open then
    return false
  end

  return focus_gallery_window()
end

function M.close()
  if gallery_popup then
    gallery_popup:unmount()
    gallery_popup = nil
  elseif gallery_winid and vim.api.nvim_win_is_valid(gallery_winid) then
    vim.api.nvim_win_close(gallery_winid, true)
  end

  gallery_winid = nil
  gallery_bufnr = nil
  all_entries = {}
  filtered_entries = {}
  selected_idx = 1
  current_query = ""
  search_context_active = false
  is_open = false
end

function M.is_open()
  return is_open
end

return M
