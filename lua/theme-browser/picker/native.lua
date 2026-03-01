local M = {}

local ok_popup, Popup = pcall(require, "nui.popup")
if not ok_popup then
  return M
end

local registry = require("theme-browser.adapters.registry")
local state = require("theme-browser.persistence.state")
local theme_service = require("theme-browser.application.theme_service")
local picker_highlights = require("theme-browser.picker.highlights")
local defaults = require("theme-browser.config.defaults")
local entry_utils = require("theme-browser.ui.entry")
local icons = require("theme-browser.util.icons")

local active_popup_winid = nil

function M.focus()
  if not active_popup_winid or not vim.api.nvim_win_is_valid(active_popup_winid) then
    return false
  end

  local ok = pcall(vim.api.nvim_set_current_win, active_popup_winid)
  return ok
end

local function get_plugin_config()
  local ok_tb, tb = pcall(require, "theme-browser")
  if not ok_tb or type(tb.get_config) ~= "function" then
    return defaults
  end
  local cfg = tb.get_config()
  if type(cfg) ~= "table" then
    return defaults
  end
  return cfg
end

local function get_keymaps()
  local cfg = get_plugin_config()
  local km = (cfg and cfg.keymaps) or {}
  local dkm = defaults.keymaps or {}

  local function pick(name)
    local value = km[name]
    if type(value) == "string" then
      return { value }
    end
    if type(value) == "table" and #value > 0 then
      return value
    end
    local fallback = dkm[name]
    if type(fallback) == "string" then
      return { fallback }
    end
    if type(fallback) == "table" and #fallback > 0 then
      return fallback
    end
    return {}
  end

  return {
    close = pick("close"),
    select = pick("select"),
    set_main = pick("set_main"),
    preview = pick("preview"),
    install = pick("install"),
    copy_repo = pick("copy_repo"),
    open_repo = pick("open_repo"),
    navigate_up = pick("navigate_up"),
    navigate_down = pick("navigate_down"),
    goto_top = pick("goto_top"),
    goto_bottom = pick("goto_bottom"),
    scroll_up = pick("scroll_up"),
    scroll_down = pick("scroll_down"),
    search = pick("search"),
    clear_search = pick("clear_search"),
    help = pick("help"),
  }
end

local function clamp_number(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

local function termcode(key)
  return vim.api.nvim_replace_termcodes(key, true, true, true)
end

local function selected_prefix()
  if type(icons.has_nerd_font) == "function" and icons.has_nerd_font() then
    return " "
  end
  return "> "
end

local function compact_variant(entry)
  if type(entry.display) == "string" and entry.display ~= "" and entry.display ~= entry.name then
    return entry.display
  end

  local variant = entry.variant
  if type(variant) ~= "string" or variant == "" then
    return nil
  end

  local prefix = entry.name .. "-"
  if variant:sub(1, #prefix) == prefix then
    variant = variant:sub(#prefix + 1)
  end

  if variant == entry.name then
    return nil
  end

  return variant
end

local function entry_key(entry)
  if type(entry) ~= "table" then
    return ""
  end

  if entry.id ~= nil then
    return tostring(entry.id)
  end

  local name = type(entry.name) == "string" and entry.name or ""
  local variant = type(entry.variant) == "string" and entry.variant or ""
  return string.format("%s::%s", name, variant)
end

local function fuzzy_match_positions(haystack, query)
  if type(haystack) ~= "string" or type(query) ~= "string" then
    return nil, nil
  end
  if query == "" then
    return 0, {}
  end

  local lowered_haystack = haystack:lower()
  local lowered_query = query:lower()
  local positions = {}

  local q_index = 1
  local q_len = #lowered_query
  local consecutive = 0
  local score = 0

  for h_index = 1, #lowered_haystack do
    if q_index > q_len then
      break
    end

    if lowered_haystack:sub(h_index, h_index) == lowered_query:sub(q_index, q_index) then
      positions[#positions + 1] = h_index
      score = score + 10 + (consecutive * 4)
      if q_index == 1 then
        score = score + math.max(0, 8 - h_index)
      end
      consecutive = consecutive + 1
      q_index = q_index + 1
    else
      consecutive = 0
    end
  end

  if q_index <= q_len then
    return nil, nil
  end

  score = score - (#lowered_haystack * 0.01)
  return score, positions
end

local function split_match_positions(item, positions)
  if type(item) ~= "table" or type(positions) ~= "table" then
    return {}, {}
  end

  local name_positions = {}
  local variant_positions = {}
  local name_len = #item.name_lower

  for _, pos in ipairs(positions) do
    if pos <= name_len then
      name_positions[#name_positions + 1] = pos
    elseif pos > (name_len + 1) then
      variant_positions[#variant_positions + 1] = pos - name_len - 1
    end
  end

  return name_positions, variant_positions
end

local STATUS_SORT_RANK = {
  current = 0,
  installed = 1,
  downloaded = 2,
  available = 3,
}

local function format_item(entry, snapshot, previewing_key, previewed_key)
  local status = entry_utils.entry_status(entry, snapshot)
  local key = entry_key(entry)

  if status ~= "current" then
    if previewing_key and previewing_key == key then
      status = "previewing"
    elseif previewed_key and previewed_key == key then
      status = "previewed"
    end
  end

  local bg = entry_utils.entry_background(entry)
  local variant = compact_variant(entry)
  local state_icons = icons.STATE_ICONS or {}

  local status_icon = state_icons.available or "○"
  local status_hl = "ThemeBrowserStatusDefault"
  if status == "current" then
    status_icon = state_icons.current or "●"
    status_hl = "ThemeBrowserStatusCurrent"
  elseif status == "previewing" then
    status_icon = state_icons.previewing or "◉"
    status_hl = "ThemeBrowserStatusPreviewing"
  elseif status == "previewed" then
    status_icon = state_icons.previewed or "◈"
    status_hl = "ThemeBrowserStatusPreviewed"
  elseif status == "installed" then
    status_icon = state_icons.installed or "◆"
    status_hl = "ThemeBrowserStatusInstalled"
  elseif status == "downloaded" then
    status_icon = state_icons.downloaded or "↓"
    status_hl = "ThemeBrowserStatusDownloaded"
  end

  local bg_icon = bg == "light" and (state_icons.light or "◑") or (state_icons.dark or "◐")
  local bg_hl = bg == "light" and "ThemeBrowserLight" or "ThemeBrowserDark"

  local name = entry.name
  local name_lower = name:lower()
  local variant_label = variant or "default"
  local variant_lower = variant_label:lower()
  local is_default_variant = variant == nil
  local colorscheme = entry.colorscheme or entry.variant or name
  local colorscheme_lower = colorscheme:lower()
  local title = ""

  local status_len = #status_icon
  local bg_len = #bg_icon
  local icon_gap = 1
  local title_gap = 2

  return {
    entry = entry,
    status = status,
    status_icon = status_icon,
    status_hl = status_hl,
    bg_icon = bg_icon,
    bg_hl = bg_hl,
    name = name,
    variant_label = variant_label,
    title = title,
    name_len = 0,
    name_cell_len = 0,
    name_hl_len = 0,
    separator_col_offset = 0,
    variant_col_offset = 0,
    variant_hl_len = 0,
    is_default_variant = is_default_variant,
    name_lower = name_lower,
    variant_lower = variant_lower,
    colorscheme_lower = colorscheme_lower,
    match_name_positions = {},
    match_variant_positions = {},
    sort_key = colorscheme_lower,
    status_col_start = 0,
    status_col_end = status_len,
    bg_col_start = status_len + icon_gap,
    bg_col_end = status_len + icon_gap + bg_len,
    name_col_start = status_len + icon_gap + bg_len + title_gap,
  }
end

local function compare_items(a, b)
  if a.name_lower ~= b.name_lower then
    return a.name_lower < b.name_lower
  end

  return a.colorscheme_lower < b.colorscheme_lower
end

local function truncate_to_width(text, max_width)
  if max_width <= 0 then
    return ""
  end

  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end

  if max_width == 1 then
    return "…"
  end

  local truncated = vim.fn.strcharpart(text, 0, max_width - 1)
  while vim.fn.strdisplaywidth(truncated) > (max_width - 1) and vim.fn.strchars(truncated) > 0 do
    truncated = vim.fn.strcharpart(truncated, 0, vim.fn.strchars(truncated) - 1)
  end

  return truncated .. "…"
end

local function pad_to_width(text, width)
  local len = vim.fn.strdisplaywidth(text)
  if len >= width then
    return text
  end
  return text .. string.rep(" ", width - len)
end

local function fit_line(text, width)
  local clipped = truncate_to_width(text, width)
  return pad_to_width(clipped, width)
end

local function calculate_column_widths(items, max_content_width)
  local max_name = 0
  local max_variant = 0

  for _, item in ipairs(items) do
    max_name = math.max(max_name, vim.fn.strdisplaywidth(item.name or ""))
    max_variant = math.max(max_variant, vim.fn.strdisplaywidth(item.variant_label or ""))
  end

  local separator_width = 3 -- " · "
  local min_name = 10
  local min_variant = 7
  local preferred_name = math.max(min_name, math.min(30, max_name))
  local preferred_variant = math.max(min_variant, math.min(34, max_variant))

  local available = math.max(min_name + min_variant + separator_width, max_content_width)
  local total = preferred_name + separator_width + preferred_variant

  if total > available then
    local overflow = total - available

    local shrink_name = math.min(overflow, math.max(0, preferred_name - min_name))
    preferred_name = preferred_name - shrink_name
    overflow = overflow - shrink_name

    if overflow > 0 then
      local shrink_variant = math.min(overflow, math.max(0, preferred_variant - min_variant))
      preferred_variant = preferred_variant - shrink_variant
    end
  end

  return preferred_name, preferred_variant, preferred_name + separator_width + preferred_variant
end

local function format_item_line(item, name_col_width, variant_col_width, content_width)
  local name_text = truncate_to_width(item.name or "", name_col_width)
  local variant_text = truncate_to_width(item.variant_label or "", variant_col_width)

  local name_cell = pad_to_width(name_text, name_col_width)
  local variant_cell = pad_to_width(variant_text, variant_col_width)
  local title = string.format("%s · %s", name_cell, variant_cell)
  local padding = content_width - vim.fn.strdisplaywidth(title)
  if padding < 0 then
    padding = 0
  end

  item.title = title
  item.name_cell_len = #name_cell
  item.name_hl_len = #name_text
  item.name_len = #name_text
  item.separator_col_offset = #name_cell + 1
  item.variant_col_offset = #name_cell + 3
  item.variant_hl_len = #variant_text

  return string.format("%s %s  %s%s", item.status_icon, item.bg_icon, title, string.rep(" ", padding))
end

local function apply_item(item, popup, close_after, callback)
  theme_service.use(item.entry.name, item.entry.variant, { notify = false }, function(success, result, err)
    vim.schedule(function()
      if not success then
        vim.notify(string.format("Theme apply failed: %s", err or "unknown error"), vim.log.levels.ERROR)
        if type(callback) == "function" then
          callback(false)
        end
        return
      end

      if close_after then
        popup:unmount()
      end
      if type(callback) == "function" then
        callback(true)
      end
    end)
  end)
end

local function install_item_async(item, done)
  local finish = done
  if type(finish) ~= "function" then
    finish = function() end
  end

  theme_service.install(
    item.entry.name,
    item.entry.variant,
    { notify = false },
    function(success, result, err)
      vim.schedule(function()
        finish(success, err)
      end)
    end
  )
end

function M.pick(opts)
  opts = opts or {}

  local entries = registry.list_entries()
  if opts.filter then
    entries = vim.tbl_filter(opts.filter, entries)
  end
  if #entries == 0 then
    vim.notify("No themes available", vim.log.levels.WARN)
    return
  end

  local initial_theme = opts.initial_theme
  if type(initial_theme) == "string" and initial_theme ~= "" then
    entries = vim.tbl_filter(function(entry)
      return entry.name == initial_theme or entry.colorscheme == initial_theme
    end, entries)
    if #entries == 0 then
      entries = registry.list_entries()
    end
  end

  local snapshot = state.build_state_snapshot and state.build_state_snapshot() or nil
  local previewing_key = nil
  local previewed_key = nil
  local all_items = {}
  local optimal_content_width = nil
  local name_column_width = nil
  local variant_column_width = nil

  local function rebuild_all_items()
    all_items = {}
    for _, entry in ipairs(entries) do
      table.insert(all_items, format_item(entry, snapshot, previewing_key, previewed_key))
    end

    table.sort(all_items, compare_items)

    if optimal_content_width and name_column_width and variant_column_width then
      for _, item in ipairs(all_items) do
        item.line = format_item_line(item, name_column_width, variant_column_width, optimal_content_width)
      end
    end
  end

  rebuild_all_items()

  local query = ""
  local items
  local index = 1
  local scroll = 1
  local syncing_cursor = false
  local last_cursor_move_time = 0
  local plugin_cfg = get_plugin_config()
  local ui_cfg = type(plugin_cfg.ui) == "table" and plugin_cfg.ui or {}
  local show_hints = ui_cfg.show_hints ~= false
  local keymaps = get_keymaps()
  local popup = nil
  local resize_autocmd_id = nil
  local search_mode = false
  local showing_help = false
  local visual_anchor = nil
  local visual_line_mode = false

  local function close_popups()
    if resize_autocmd_id then
      pcall(vim.api.nvim_del_autocmd, resize_autocmd_id)
      resize_autocmd_id = nil
    end

    if popup then
      pcall(function()
        popup:unmount()
      end)
    end

    active_popup_winid = nil
  end

  local function first_key(keys)
    if type(keys) ~= "table" or #keys == 0 then
      return "?"
    end
    return keys[1]
  end

  local function keycap(keys)
    return string.format("[%s]", first_key(keys))
  end

  local function fit_hint_parts(width, parts)
    local line = ""
    for _, part in ipairs(parts) do
      local candidate = line == "" and (" " .. part) or (line .. "  ·  " .. part)
      if vim.fn.strdisplaywidth(candidate) > width then
        break
      end
      line = candidate
    end
    return line ~= "" and line or (" " .. parts[1])
  end

  local function hint_text(width)
    if search_mode then
      return fit_hint_parts(width, {
        string.format("%s help", keycap(keymaps.help)),
        "[Enter] done",
        "[Esc] exit",
        "[BS] erase",
      })
    end

    local parts = {
      string.format("%s help", keycap(keymaps.help)),
      string.format("%s fuzzy", keycap(keymaps.search)),
      string.format("%s apply", keycap(keymaps.select)),
    }

    local current = (#items > 0 and items[index]) or nil
    if current and current.status then
      if current.status == "installed" or current.status == "current" or current.status == "previewed" then
        table.insert(parts, string.format("%s preview", keycap(keymaps.preview)))
      else
        table.insert(parts, string.format("%s install", keycap(keymaps.install)))
      end
      table.insert(parts, string.format("%s set-main", keycap(keymaps.set_main)))
    end

    return fit_hint_parts(width, parts)
  end

  local function help_lines()
    return {
      " Theme Browser Help",
      "",
      " Core",
      string.format("  %s  Apply and close", keycap(keymaps.select)),
      string.format("  %s  Apply and keep open", keycap(keymaps.set_main)),
      string.format("  %s  Live fuzzy search", keycap(keymaps.search)),
      string.format("  %s  Toggle this help", keycap(keymaps.help)),
      "",
      " Actions",
      string.format("  %s  Preview selected theme", keycap(keymaps.preview)),
      string.format("  %s  Install selected theme", keycap(keymaps.install)),
      string.format("  %s  Clear current search", keycap(keymaps.clear_search)),
      string.format("  %s  Copy repository URL", keycap(keymaps.copy_repo)),
      string.format("  %s  Open repository URL", keycap(keymaps.open_repo)),
      "",
      " Navigation",
      string.format("  %s/%s  Move selection", keycap(keymaps.navigate_up), keycap(keymaps.navigate_down)),
      string.format("  %s/%s  Jump to top/bottom", keycap(keymaps.goto_top), keycap(keymaps.goto_bottom)),
      string.format("  %s/%s  Scroll half page", keycap(keymaps.scroll_up), keycap(keymaps.scroll_down)),
      "",
      string.format("  %s or %s  Close help", keycap(keymaps.help), keycap(keymaps.close)),
    }
  end

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  local defaults_ui = type(defaults.ui) == "table" and defaults.ui or {}
  local width_ratio = clamp_number(
    type(ui_cfg.window_width) == "number" and ui_cfg.window_width or defaults_ui.window_width or 0.6,
    0.45,
    0.9
  )
  local height_ratio = clamp_number(
    type(ui_cfg.window_height) == "number" and ui_cfg.window_height or defaults_ui.window_height or 0.5,
    0.4,
    0.85
  )
  local border_style = type(ui_cfg.border) == "string" and ui_cfg.border ~= "" and ui_cfg.border or "rounded"
  local min_content_width = 36
  local target_popup_width =
    clamp_number(math.floor(editor_width * width_ratio), 48, math.max(48, editor_width - 4))
  local max_content_width = math.max(min_content_width, math.min(110, target_popup_width - 6))
  local content_width
  name_column_width, variant_column_width, content_width =
    calculate_column_widths(all_items, max_content_width)
  optimal_content_width = math.max(min_content_width, math.min(max_content_width, content_width))
  local popup_width = clamp_number(optimal_content_width + 6, 48, math.max(48, editor_width - 4))
  local min_height = 15
  local max_height =
    clamp_number(math.floor(editor_height * height_ratio), 15, math.max(15, editor_height - 4))
  local footer_line_count = show_hints and 2 or 1
  local popup_height = math.max(min_height, math.min(max_height, #all_items + 3 + footer_line_count))
  local current_width = popup_width
  local current_height = popup_height

  rebuild_all_items()

  items = vim.deepcopy(all_items)

  popup = Popup({
    enter = true,
    focusable = true,
    relative = "editor",
    border = {
      style = border_style,
      text = {
        top = " Theme Browser ",
        top_align = "center",
      },
    },
    position = {
      row = math.floor((editor_height - popup_height) / 2),
      col = math.floor((editor_width - popup_width) / 2),
    },
    size = {
      width = popup_width,
      height = popup_height,
    },
    win_options = {
      cursorline = true,
      number = false,
      relativenumber = false,
      wrap = false,
      scrolloff = 0,
      sidescrolloff = 0,
    },
  })

  local function visible_capacity()
    if not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
      return 15
    end
    local height = vim.api.nvim_win_get_height(popup.winid)
    local reserved = 3 + footer_line_count -- search, top divider, bottom divider, footer lines
    return math.max(1, height - reserved)
  end

  local function ensure_visible()
    local cap = visible_capacity()
    if index < scroll then
      scroll = index
    elseif index > (scroll + cap - 1) then
      scroll = index - cap + 1
    end

    if scroll < 1 then
      scroll = 1
    end

    local max_scroll = math.max(1, #items - cap + 1)
    if scroll > max_scroll then
      scroll = max_scroll
    end
  end

  local function move_cursor_to_selection()
    if not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
      return
    end
    ensure_visible()
    local row = (index - scroll + 1)
    syncing_cursor = true
    pcall(vim.api.nvim_win_set_cursor, popup.winid, { row, 0 })
    syncing_cursor = false
  end

  local function get_visual_range()
    if not visual_anchor then
      return nil, nil
    end
    local start_idx = math.min(visual_anchor, index)
    local end_idx = math.max(visual_anchor, index)
    return start_idx, end_idx
  end

  local function exit_visual_mode()
    visual_anchor = nil
    visual_line_mode = false
  end

  local function render()
    ensure_visible()

    local win_width = current_width - 2
    local divider = string.rep("─", win_width)
    local selected_row_prefix = selected_prefix()
    local normal_row_prefix = "  "
    local search_icon = (type(icons.has_nerd_font) == "function" and icons.has_nerd_font()) and "" or "/"
    local query_display = search_mode and query or (query ~= "" and query or "type / to fuzzy-filter themes")
    local query_cursor = search_mode and "" or ""
    local prompt_text = fit_line(
      string.format(" %s  %s%s%s", search_icon, query_display, query_cursor, search_mode and "  [LIVE]" or ""),
      win_width
    )

    local lines = {}

    if showing_help then
      for _, line in ipairs(help_lines()) do
        table.insert(lines, fit_line(line, win_width))
      end
      table.insert(lines, divider)
      table.insert(lines, fit_line(" Press ? to toggle help, or q/Esc to return", win_width))

      vim.bo[popup.bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
      vim.bo[popup.bufnr].modifiable = false

      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserName", 0, 0, -1)
      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserDivider", #lines - 2, 0, -1)
      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserSubtle", #lines - 1, 0, -1)

      pcall(vim.api.nvim_win_set_cursor, popup.winid, { 1, 0 })
      pcall(vim.cmd, "redraw")
      return
    end

    local cap = visible_capacity()
    local first = scroll
    local last = math.min(#items, scroll + cap - 1)

    for i = first, last do
      local item = items[i]
      local prefix = (i == index) and selected_row_prefix or normal_row_prefix
      table.insert(lines, prefix .. item.line)
    end

    table.insert(lines, divider)

    local status_left = string.format("%d/%d selected", #items == 0 and 0 or index, #items)
    local status_right = string.format("showing %d-%d", #items == 0 and 0 or first, #items == 0 and 0 or last)
    local left_len = vim.fn.strdisplaywidth(status_left)
    local right_len = vim.fn.strdisplaywidth(status_right)
    local space_available = win_width - left_len - right_len - 2
    local status_line
    if space_available >= 2 then
      status_line = string.format(" %s%s%s", status_left, string.rep(" ", space_available), status_right)
    else
      status_line = fit_line(string.format(" %s  %s", status_left, status_right), win_width)
    end

    table.insert(lines, status_line)
    table.insert(lines, prompt_text)
    if show_hints then
      table.insert(lines, fit_line(hint_text(win_width), win_width))
    end

    vim.bo[popup.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
    vim.bo[popup.bufnr].modifiable = false

    local divider_row = #items == 0 and 0 or (last - first)
    vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserDivider", divider_row, 0, -1)

    for i = first, last do
      local item = items[i]
      local row = (i - first + 1)
      local row_prefix = (i == index) and selected_row_prefix or normal_row_prefix
      local prefix_offset = #row_prefix
      local status_start = item.status_col_start + prefix_offset
      local status_end = item.status_col_end + prefix_offset
      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, item.status_hl, row - 1, status_start, status_end)
      local bg_start = item.bg_col_start + prefix_offset
      local bg_end = item.bg_col_end + prefix_offset
      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, item.bg_hl, row - 1, bg_start, bg_end)
      local name_start = item.name_col_start + prefix_offset
      local name_end = name_start + item.name_len
      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserName", row - 1, name_start, name_end)
      if item.separator_col_offset then
        local separator_start = name_start + item.separator_col_offset
        vim.api.nvim_buf_add_highlight(
          popup.bufnr,
          -1,
          "ThemeBrowserSeparator",
          row - 1,
          separator_start,
          separator_start + 1
        )
      end
      if item.variant_col_offset then
        local variant_start = name_start + item.variant_col_offset
        local variant_end = variant_start + item.variant_hl_len
        local variant_hl = item.is_default_variant and "ThemeBrowserVariantDefault" or "ThemeBrowserVariant"
        vim.api.nvim_buf_add_highlight(popup.bufnr, -1, variant_hl, row - 1, variant_start, variant_end)
      end

      for _, pos in ipairs(item.match_name_positions or {}) do
        if pos >= 1 and pos <= item.name_hl_len then
          local col = name_start + (pos - 1)
          vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserFuzzyMatch", row - 1, col, col + 1)
        end
      end

      if item.variant_col_offset then
        local variant_start = name_start + item.variant_col_offset
        for _, pos in ipairs(item.match_variant_positions or {}) do
          if pos >= 1 and pos <= item.variant_hl_len then
            local col = variant_start + (pos - 1)
            vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserFuzzyMatch", row - 1, col, col + 1)
          end
        end
      end

      local visual_start, visual_end = get_visual_range()
      if visual_start and i >= visual_start and i <= visual_end then
        vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserVisual", row - 1, 0, -1)
      end

      if i == index then
        vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserSelected", row - 1, 0, -1)
      end
    end

    local bottom_divider_row = #lines - (show_hints and 2 or 1)
    vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserDivider", bottom_divider_row - 1, 0, -1)

    local prompt_row = #lines - (show_hints and 1 or 0)
    vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserPrompt", prompt_row - 1, 0, -1)
    vim.api.nvim_buf_add_highlight(
      popup.bufnr,
      -1,
      "ThemeBrowserPromptIcon",
      prompt_row - 1,
      1,
      1 + #search_icon
    )

    move_cursor_to_selection()

    local status_row = prompt_row - 1
    vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserSubtle", status_row - 1, 0, -1)
    if show_hints then
      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserSubtle", #lines - 1, 0, -1)
    end

    -- Force immediate visual refresh so live-search input is visible per keystroke.
    pcall(vim.cmd, "redraw")
  end
  local function sync_selection_from_cursor()
    if syncing_cursor or not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
      return
    end

    local row = vim.api.nvim_win_get_cursor(popup.winid)[1]
    local candidate = scroll + (row - 1)
    if #items == 0 then
      candidate = 1
    else
      if candidate < 1 then
        candidate = 1
      end
      if candidate > #items then
        candidate = #items
      end
    end

    if candidate ~= index then
      index = candidate
      render()
    end
  end
  local function clamp_index()
    if #items == 0 then
      index = 1
      return
    end
    if index < 1 then
      index = 1
    end
    if index > #items then
      index = #items
    end
  end

  local function apply_filter(new_query, preserve_index)
    query = type(new_query) == "string" and new_query or ""
    local normalized_query = vim.trim(query)
    if normalized_query == "" then
      items = vim.deepcopy(all_items)
    else
      local query_tokens = {}
      for token in normalized_query:gmatch("%S+") do
        query_tokens[#query_tokens + 1] = token:lower()
      end

      items = {}
      for _, item in ipairs(all_items) do
        local total_score = 0
        local collected_positions = {}
        local matched = true

        for _, token in ipairs(query_tokens) do
          local score, positions = fuzzy_match_positions(item.sort_key, token)
          if not score then
            matched = false
            break
          end
          total_score = total_score + score
          for _, pos in ipairs(positions) do
            collected_positions[pos] = true
          end
        end

        if matched then
          local merged_positions = {}
          for pos in pairs(collected_positions) do
            merged_positions[#merged_positions + 1] = pos
          end
          table.sort(merged_positions)

          local filtered_item = vim.deepcopy(item)
          filtered_item.match_score = total_score - ((#query_tokens - 1) * 0.5)
          filtered_item.match_name_positions, filtered_item.match_variant_positions =
            split_match_positions(filtered_item, merged_positions)
          table.insert(items, filtered_item)
        end
      end

      table.sort(items, function(a, b)
        if a.match_score == b.match_score then
          return compare_items(a, b)
        end
        return a.match_score > b.match_score
      end)
    end

    if not preserve_index then
      index = 1
      scroll = 1
    end

    clamp_index()

    if preserve_index then
      ensure_visible()
    end

    render()
  end

  local map_opts = { buffer = popup.bufnr, nowait = true, silent = true }
  local search_passthrough_keys = {}

  local function register_search_passthrough_keys(keys)
    if type(keys) ~= "table" then
      return
    end
    for _, lhs in ipairs(keys) do
      if type(lhs) == "string" and lhs ~= "" then
        if lhs:match("^<[CMAS]%-.+>$") then
          search_passthrough_keys[termcode(lhs)] = lhs
        end
      end
    end
  end

  register_search_passthrough_keys(keymaps.navigate_up)
  register_search_passthrough_keys(keymaps.navigate_down)
  register_search_passthrough_keys(keymaps.goto_top)
  register_search_passthrough_keys(keymaps.goto_bottom)
  register_search_passthrough_keys(keymaps.scroll_up)
  register_search_passthrough_keys(keymaps.scroll_down)
  register_search_passthrough_keys(keymaps.select)
  register_search_passthrough_keys(keymaps.set_main)
  register_search_passthrough_keys(keymaps.preview)
  register_search_passthrough_keys(keymaps.install)
  register_search_passthrough_keys(keymaps.copy_repo)
  register_search_passthrough_keys(keymaps.open_repo)
  register_search_passthrough_keys(keymaps.help)
  register_search_passthrough_keys(keymaps.close)

  local function map_keys(keys, fn, opts_for_map)
    local allow_in_help = type(opts_for_map) == "table" and opts_for_map.allow_in_help == true
    if type(keys) ~= "table" then
      return
    end
    for _, lhs in ipairs(keys) do
      vim.keymap.set("n", lhs, function()
        if showing_help and not allow_in_help then
          return
        end
        fn()
      end, map_opts)
    end
  end

  map_keys(keymaps.navigate_down, function()
    if #items == 0 then
      return
    end
    if index >= #items then
      index = 1
    else
      index = index + 1
    end
    render()
  end)

  map_keys(keymaps.navigate_up, function()
    if #items == 0 then
      return
    end
    if index <= 1 then
      index = #items
    else
      index = index - 1
    end
    render()
  end)

  map_keys(keymaps.goto_top, function()
    if #items == 0 then
      return
    end
    index = 1
    render()
  end)

  map_keys(keymaps.goto_bottom, function()
    if #items == 0 then
      return
    end
    index = #items
    render()
  end)

  local function page_step()
    return math.max(1, math.floor(visible_capacity() * 0.5))
  end

  map_keys(keymaps.scroll_down, function()
    if #items == 0 then
      return
    end
    index = math.min(#items, index + page_step())
    render()
  end)

  map_keys(keymaps.scroll_up, function()
    if #items == 0 then
      return
    end
    index = math.max(1, index - page_step())
    render()
  end)

  vim.keymap.set("n", "<ScrollWheelDown>", function()
    if showing_help then
      return
    end
    if #items == 0 then
      return
    end
    index = math.min(#items, index + 1)
    render()
  end, map_opts)

  vim.keymap.set("n", "<ScrollWheelUp>", function()
    if showing_help then
      return
    end
    if #items == 0 then
      return
    end
    index = math.max(1, index - 1)
    render()
  end, map_opts)

  local function yank_selection()
    local start_idx, end_idx = get_visual_range()
    if not start_idx then
      return
    end
    local lines = {}
    for i = start_idx, end_idx do
      local item = items[i]
      if item and item.entry then
        local colorscheme = item.entry.colorscheme or item.entry.variant or item.entry.name
        table.insert(lines, colorscheme)
      end
    end
    if #lines > 0 then
      local text = table.concat(lines, "\n")
      vim.fn.setreg('"', text)
      vim.fn.setreg("+", text)
      vim.notify(string.format("Yanked %d theme%s", #lines, #lines == 1 and "" or "s"), vim.log.levels.INFO)
    end
    exit_visual_mode()
    render()
  end

  map_keys(keymaps.visual, function()
    if #items == 0 then
      return
    end
    if visual_anchor then
      exit_visual_mode()
    else
      visual_anchor = index
      visual_line_mode = false
    end
    render()
  end)

  map_keys(keymaps.visual_line, function()
    if #items == 0 then
      return
    end
    if visual_anchor and visual_line_mode then
      exit_visual_mode()
    else
      visual_anchor = index
      visual_line_mode = true
    end
    render()
  end)

  map_keys(keymaps.yank, function()
    if visual_anchor then
      yank_selection()
    end
  end)

  map_keys(keymaps.select, function()
    if #items == 0 then
      return
    end
    apply_item(items[index], popup, true, nil)
  end)

  map_keys(keymaps.set_main, function()
    if #items == 0 then
      return
    end
    local item = items[index]
    apply_item(item, popup, false, function(ok)
      if not ok then
        return
      end
      previewing_key = nil
      previewed_key = nil
      snapshot = state.build_state_snapshot and state.build_state_snapshot() or nil
      rebuild_all_items()
      apply_filter(query, true)
    end)
  end)

  map_keys(keymaps.preview, function()
    if #items == 0 then
      return
    end
    local item = items[index]
    local requested_key = entry_key(item.entry)
    previewing_key = requested_key
    previewed_key = nil
    rebuild_all_items()
    apply_filter(query, true)

    local status = theme_service.preview(item.entry.name, item.entry.variant, {
      notify = true,
      install_missing = true,
      on_preview_applied = function()
        previewing_key = nil
        previewed_key = requested_key
        snapshot = state.build_state_snapshot and state.build_state_snapshot() or nil
        rebuild_all_items()
        apply_filter(query, true)
      end,
      on_preview_failed = function()
        if previewing_key == requested_key then
          previewing_key = nil
        end
        rebuild_all_items()
        apply_filter(query, true)
      end,
    })
    if status ~= 0 then
      if previewing_key == requested_key then
        previewing_key = nil
      end
      rebuild_all_items()
      apply_filter(query, true)
      vim.notify(string.format("Preview failed for %s", item.entry.name), vim.log.levels.ERROR)
    end
  end)

  map_keys(keymaps.install, function()
    if #items == 0 then
      return
    end
    local item = items[index]
    install_item_async(item, function(ok, err)
      if ok then
        if type(state.mark_theme) == "function" then
          state.mark_theme(item.entry.name, item.entry.variant)
        end
        vim.notify(string.format("Installed and marked %s", item.entry.name), vim.log.levels.INFO)
        if previewed_key == entry_key(item.entry) then
          previewed_key = nil
        end
        snapshot = state.build_state_snapshot and state.build_state_snapshot() or nil
        rebuild_all_items()
        apply_filter(query, true)
      else
        vim.notify(
          string.format("Failed to install %s: %s", item.entry.name, err or "unknown error"),
          vim.log.levels.ERROR
        )
      end
    end)
  end)

  map_keys(keymaps.search, function()
    search_mode = true
    render()

    local esc = termcode("<Esc>")
    local c_bracket = termcode("<C-[>")
    local cr = termcode("<CR>")
    local bs = termcode("<BS>")
    local del = termcode("<Del>")
    local c_h = termcode("<C-h>")
    local c_u = termcode("<C-u>")
    local c_w = termcode("<C-w>")
    local c_c = termcode("<C-c>")
    local raw_c_c = "\3"
    local search_key = first_key(keymaps.search)
    local replay_lhs = nil

    while popup and popup.winid and vim.api.nvim_win_is_valid(popup.winid) do
      local ok, key = pcall(vim.fn.getcharstr)
      if not ok or type(key) ~= "string" then
        break
      end

      if key == cr then
        break
      end

      if key == esc or key == c_bracket or key == c_c or key == raw_c_c then
        break
      end

      local passthrough_lhs = search_passthrough_keys[key]
      if passthrough_lhs ~= nil then
        replay_lhs = passthrough_lhs
        break
      end

      if key == search_key then
        apply_filter("", false)
      elseif key == bs or key == del or key == c_h then
        if query ~= "" then
          query = vim.fn.strcharpart(query, 0, math.max(0, vim.fn.strchars(query) - 1))
          apply_filter(query, false)
        end
      elseif key == c_w then
        local stripped = query:gsub("%s+$", "")
        local next_query = stripped:gsub("%S+$", "")
        apply_filter(vim.trim(next_query), false)
      else
        if not (key:find("^<") and key:find(">$")) then
          apply_filter(query .. key, false)
        end
      end
    end

    search_mode = false
    render()

    if replay_lhs then
      vim.schedule(function()
        if not popup or not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
          return
        end
        vim.api.nvim_feedkeys(termcode(replay_lhs), "n", false)
      end)
    end
  end)

  map_keys(keymaps.clear_search, function()
    apply_filter("")
  end)

  map_keys(keymaps.help, function()
    showing_help = not showing_help
    render()
  end, { allow_in_help = true })

  local function selected_repo_url()
    if #items == 0 then
      return nil
    end

    local item = items[index]
    local repo = item.entry.repo
    if type(repo) ~= "string" or repo == "" then
      return nil
    end

    return string.format("https://github.com/%s", repo)
  end

  map_keys(keymaps.copy_repo, function()
    local url = selected_repo_url()
    if not url then
      vim.notify("No repository URL available", vim.log.levels.WARN)
      return
    end

    vim.fn.setreg("+", url)
    vim.fn.setreg('"', url)
    vim.notify(string.format("Copied: %s", url), vim.log.levels.INFO)
  end)

  map_keys(keymaps.open_repo, function()
    local url = selected_repo_url()
    if not url then
      vim.notify("No repository URL available", vim.log.levels.WARN)
      return
    end

    if type(vim.ui.open) ~= "function" then
      vim.notify("vim.ui.open is unavailable on this Neovim version", vim.log.levels.WARN)
      return
    end

    local ok_open, open_result, open_err = pcall(vim.ui.open, url)
    if not ok_open then
      vim.notify(string.format("Failed to open URL: %s", open_result), vim.log.levels.ERROR)
      return
    end

    if open_result == nil then
      vim.notify(string.format("Failed to open URL: %s", open_err or "unknown error"), vim.log.levels.ERROR)
      return
    end
  end)

  map_keys(keymaps.close, function()
    if showing_help then
      showing_help = false
      render()
      return
    end
    close_popups()
  end, { allow_in_help = true })

  local resize_step = 5

  local function clamp_size(w, h)
    local min_w = 40
    local min_h = 15
    local max_w = math.max(1, vim.o.columns - 4)
    local max_h = math.max(1, vim.o.lines - 4)
    local effective_min_w = math.min(min_w, max_w)
    local effective_min_h = math.min(min_h, max_h)
    return math.max(effective_min_w, math.min(max_w, w)), math.max(effective_min_h, math.min(max_h, h))
  end

  local function apply_size()
    if not popup or not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
      return
    end

    local w, h = clamp_size(current_width, current_height)
    current_width, current_height = w, h
    local resized_max_content_width = math.max(24, w - 6)
    local resized_content_width
    name_column_width, variant_column_width, resized_content_width =
      calculate_column_widths(all_items, resized_max_content_width)
    optimal_content_width = math.min(resized_max_content_width, resized_content_width)

    local row = math.max(0, math.floor((vim.o.lines - h) / 2))
    local col = math.max(0, math.floor((vim.o.columns - w) / 2))
    popup:update_layout({
      position = { row = row, col = col },
      size = { width = w, height = h },
    })

    rebuild_all_items()
    apply_filter(query, true)
  end

  vim.keymap.set("n", "<C-w>+", function()
    current_height = current_height + resize_step
    apply_size()
  end, map_opts)

  vim.keymap.set("n", "<C-w>-", function()
    current_height = current_height - resize_step
    apply_size()
  end, map_opts)

  vim.keymap.set("n", "<C-w>>", function()
    current_width = current_width + resize_step
    apply_size()
  end, map_opts)

  vim.keymap.set("n", "<C-w><", function()
    current_width = current_width - resize_step
    apply_size()
  end, map_opts)

  vim.keymap.set("n", "=", function()
    local ew, eh = vim.o.columns, vim.o.lines
    current_width = math.max(math.min(80, math.floor(ew * 0.7)), math.floor(ew * 0.5))
    current_height = math.max(math.min(25, math.floor(eh * 0.6)), math.floor(eh * 0.5))
    apply_size()
  end, map_opts)

  popup:mount()
  active_popup_winid = popup.winid
  picker_highlights.setup()

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = popup.bufnr,
    callback = function()
      last_cursor_move_time = vim.loop.now()
      vim.defer_fn(function()
        if vim.loop.now() - last_cursor_move_time >= 100 then
          sync_selection_from_cursor()
        end
      end, 100)
    end,
  })

  resize_autocmd_id = vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      apply_size()
    end,
  })

  vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
    buffer = popup.bufnr,
    once = true,
    callback = function()
      close_popups()
    end,
  })

  render()
end

return M
