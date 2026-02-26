local M = {}

local has_nui_popup, NuiPopup = pcall(require, "nui.popup")

local log = require("theme-browser.util.log")
local actions = require("theme-browser.ui.gallery.actions")
local highlights = require("theme-browser.ui.highlights")
local keymaps = require("theme-browser.ui.gallery.keymaps")
local model = require("theme-browser.ui.gallery.model")
local renderer = require("theme-browser.ui.gallery.renderer")
local state_mod = require("theme-browser.ui.gallery.state")

local session = state_mod.new(vim.api.nvim_create_namespace("theme-browser-gallery"))

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

local function clear_search_context()
  if vim.v.hlsearch == 1 then
    vim.cmd("nohlsearch")
  end
  vim.fn.setreg("/", "")
  session.search_context_active = false
end

local function set_cursor_to_selected()
  model.set_cursor_to_selected(session, state_mod)
end

local function first_key(keys, fallback)
  if type(keys) == "table" and type(keys[1]) == "string" and keys[1] ~= "" then
    return keys[1]
  end
  if type(keys) == "string" and keys ~= "" then
    return keys
  end
  return fallback
end

local function update_topbar()
  if not session.winid or not vim.api.nvim_win_is_valid(session.winid) then
    return
  end

  local config = get_config()
  local keymaps_cfg = config.keymaps or {}

  local down = first_key(keymaps_cfg.navigate_down, "j")
  local up = first_key(keymaps_cfg.navigate_up, "k")
  local top = first_key(keymaps_cfg.goto_top, "gg")
  local bottom = first_key(keymaps_cfg.goto_bottom, "G")
  local use = first_key(keymaps_cfg.select, "<CR>")
  local preview = first_key(keymaps_cfg.preview, "p")
  local _install = first_key(keymaps_cfg.install, "i")
  local close = first_key(keymaps_cfg.close, "q")
  local copy = first_key(keymaps_cfg.copy_repo, "Y")

  local crumbs = {
    "Theme Browser",
    string.format("%s/%s move", down, up),
    string.format("%s/%s bounds", top, bottom),
    "/ search",
    "n/N jump",
    string.format("%s use", use),
    string.format("%s preview", preview),
    string.format("%s copy", copy),
    string.format("%s close", close),
  }

  vim.api.nvim_set_option_value("winbar", " " .. table.concat(crumbs, "  >  "), { win = session.winid })
end

local function render()
  update_topbar()
  renderer.render(session, state_mod, set_cursor_to_selected)
end

local function get_selected_entry()
  return model.get_selected_entry(session, state_mod)
end

local function focus_gallery_window()
  return actions.focus_window(session)
end

local function preview_selected_on_move()
  actions.preview_selected_on_move(session, get_selected_entry, get_config)
end

local function sync_selection_to_cursor(opts)
  return model.sync_selection_to_cursor(session, state_mod, opts, render)
end

local function navigate_to(idx)
  if #session.filtered_entries == 0 then
    session.selected_idx = 1
    return
  end

  if idx < 1 then
    idx = 1
  elseif idx > #session.filtered_entries then
    idx = #session.filtered_entries
  end

  session.selected_idx = idx
  render()
  preview_selected_on_move()
end

local function create_gallery_window()
  local config = get_config()
  local width, height = get_window_size()

  if has_nui_popup then
    session.popup = NuiPopup({
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

    session.popup:mount()
    session.bufnr = session.popup.bufnr
    session.winid = session.popup.winid
  else
    session.bufnr = vim.api.nvim_create_buf(false, true)
    session.winid = vim.api.nvim_open_win(session.bufnr, true, {
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

    vim.api.nvim_set_option_value("winhighlight", "Normal:Normal,FloatBorder:Normal", { win = session.winid })
    vim.api.nvim_set_option_value("cursorline", true, { win = session.winid })
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = session.bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = session.bufnr })
  vim.api.nvim_set_option_value("filetype", "theme-browser-gallery", { buf = session.bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = session.bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = session.bufnr })

  session.is_open = true
end

local function apply_selected()
  actions.apply_selected(session, get_selected_entry, render)
end

local function preview_selected()
  actions.preview_selected(session, get_selected_entry, render)
end

local function install_selected()
  actions.install_selected(session, get_selected_entry, render)
end

local function copy_repo()
  actions.copy_repo(session, get_selected_entry)
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

---@param query string|nil
function M.open(query)
  if session.is_open then
    if focus_gallery_window() then
      return
    end
    M.close()
  end

  local registry = require("theme-browser.adapters.registry")
  if type(registry.is_initialized) == "function" and not registry.is_initialized() then
    registry.initialize(get_config().registry_path)
  end

  session.all_entries = registry.list_entries()
  if #session.all_entries == 0 then
    log.warn("Theme registry is empty or not loaded")
  end

  session.current_query = query or ""
  session.search_context_active = false
  session.last_cursor_preview_id = nil
  session.filtered_entries = model.filter_entries(session.all_entries, session.current_query)
  session.selected_idx = 1

  local current = require("theme-browser.persistence.state").get_current_theme()
  model.select_current(session, current)

  create_gallery_window()
  highlights.apply()
  focus_gallery_window()

  keymaps.setup(session, get_config, {
    navigate_to = navigate_to,
    apply_selected = apply_selected,
    preview_selected = preview_selected,
    install_selected = install_selected,
    clear_search_context = clear_search_context,
    close = M.close,
    focus_gallery_window = focus_gallery_window,
    sync_selection_to_cursor = sync_selection_to_cursor,
    preview_selected_on_move = preview_selected_on_move,
    copy_repo = copy_repo,
  })

  render()
  focus_gallery_window()
end

function M.focus()
  if not session.is_open then
    return false
  end

  return focus_gallery_window()
end

function M.close()
  if session.winid and vim.api.nvim_win_is_valid(session.winid) then
    pcall(vim.api.nvim_set_option_value, "winbar", "", { win = session.winid })
  end

  if session.popup then
    session.popup:unmount()
  elseif session.winid and vim.api.nvim_win_is_valid(session.winid) then
    vim.api.nvim_win_close(session.winid, true)
  end

  state_mod.reset(session)
end

function M.is_open()
  return session.is_open
end

return M
