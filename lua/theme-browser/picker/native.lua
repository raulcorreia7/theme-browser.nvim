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
    navigate_up = pick("navigate_up"),
    navigate_down = pick("navigate_down"),
    goto_top = pick("goto_top"),
    goto_bottom = pick("goto_bottom"),
    search = pick("search"),
    clear_search = pick("clear_search"),
  }
end

local function entry_background(entry)
  local meta = entry.meta or {}
  if meta.background == "light" or meta.background == "dark" then
    return meta.background
  end
  if type(meta.opts_o) == "table" and (meta.opts_o.background == "light" or meta.opts_o.background == "dark") then
    return meta.opts_o.background
  end
  return "dark"
end

local function entry_status(entry, snapshot)
  local current = state.get_current_theme()
  if current and current.name == entry.name and (current.variant or "") == (entry.variant or "") then
    return "current"
  end

  local entry_state = state.get_entry_state(entry, { snapshot = snapshot }) or {}
  if entry_state.installed then
    return "installed"
  end
  if entry_state.cached then
    return "downloaded"
  end
  return "available"
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

local function format_item(entry, snapshot)
  local status = entry_status(entry, snapshot)
  local bg = entry_background(entry)
  local variant = compact_variant(entry)

  local status_icon = "○"
  local status_hl = "ThemeBrowserStatusDefault"
  if status == "current" then
    status_icon = "✓"
    status_hl = "ThemeBrowserStatusCurrent"
  elseif status == "installed" then
    status_icon = "●"
    status_hl = "ThemeBrowserStatusInstalled"
  elseif status == "downloaded" then
    status_icon = "◐"
    status_hl = "ThemeBrowserStatusDownloaded"
  end

  local bg_icon = bg == "light" and "◐" or "◑"
  local bg_hl = bg == "light" and "ThemeBrowserLight" or "ThemeBrowserDark"

  local name = entry.name
  local title = name
  local right = ""
  if variant then
    title = string.format("[%s] %s", name, variant)
    right = variant
  end

  return {
    entry = entry,
    status = status,
    status_icon = status_icon,
    status_hl = status_hl,
    bg_icon = bg_icon,
    bg_hl = bg_hl,
    name = name,
    title = title,
    right = right,
    sort_key = string.format("%s %s", name:lower(), (variant or ""):lower()),
    line = string.format("%s %s %-48s", status_icon, bg_icon, title),
  }
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

  theme_service.install(item.entry.name, item.entry.variant, { notify = false }, function(success, result, err)
    vim.schedule(function()
      finish(success, err)
    end)
  end)
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
  local all_items = {}
  for _, entry in ipairs(entries) do
    table.insert(all_items, format_item(entry, snapshot))
  end

  table.sort(all_items, function(a, b)
    return a.sort_key < b.sort_key
  end)

  local query = ""
  local items = vim.deepcopy(all_items)
  local index = 1
  local scroll = 1
  local syncing_cursor = false
  local last_cursor_move_time = 0
  local keymaps = get_keymaps()
  local hint_popup = nil

  local function close_popups()
    if hint_popup then
      pcall(function()
        hint_popup:unmount()
      end)
      hint_popup = nil
    end

    if popup then
      pcall(function()
        popup:unmount()
      end)
    end
  end

  local function first_key(keys)
    if type(keys) ~= "table" or #keys == 0 then
      return "?"
    end
    return keys[1]
  end

  local function hint_text()
    return string.format(
      " %s apply+quit  %s set-main  %s preview  %s install  %s copy  %s search  %s clear  %s/%s move  %s close",
      first_key(keymaps.select),
      first_key(keymaps.set_main),
      first_key(keymaps.preview),
      first_key(keymaps.install),
      first_key(keymaps.copy_repo),
      first_key(keymaps.search),
      first_key(keymaps.clear_search),
      first_key(keymaps.navigate_down),
      first_key(keymaps.navigate_up),
      first_key(keymaps.close)
    )
  end

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = " Select Theme ",
        top_align = "center",
      },
    },
    position = "50%",
    size = {
      width = "60%",
      height = "40%",
    },
    win_options = {
      cursorline = true,
    },
  })

  local function visible_capacity()
    if not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
      return 15
    end
    local height = vim.api.nvim_win_get_height(popup.winid)
    local reserved = 4 -- search, divider, bottom divider, status line
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
    local row = (index - scroll + 1) + 2
    syncing_cursor = true
    pcall(vim.api.nvim_win_set_cursor, popup.winid, { row, 0 })
    syncing_cursor = false
  end
  local function render()
    ensure_visible()

    local lines = {
      string.format(" Search: %s", query ~= "" and query or "(use configured search key)"),
      string.rep("-", 72),
    }

    local cap = visible_capacity()
    local first = scroll
    local last = math.min(#items, scroll + cap - 1)

    for i = first, last do
      local item = items[i]
      local prefix = (i == index) and "> " or "  "
      table.insert(lines, prefix .. item.line)
    end

    table.insert(lines, string.rep("-", 72))
    table.insert(lines, string.format(" %d/%d selected  showing %d-%d", #items == 0 and 0 or index, #items, #items == 0 and 0 or first, #items == 0 and 0 or last))

    vim.bo[popup.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
    vim.bo[popup.bufnr].modifiable = false

    for i = first, last do
      local item = items[i]
      local row = (i - first + 1) + 2
      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, item.status_hl, row - 1, 2, 4)
      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, item.bg_hl, row - 1, 5, 7)
      vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserName", row - 1, 8, -1)
      if item.right ~= "" then
        vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserVariant", row - 1, 8, 24)
      end
      if i == index then
        vim.api.nvim_buf_add_highlight(popup.bufnr, -1, "ThemeBrowserSelected", row - 1, 0, -1)
      end
    end

    move_cursor_to_selection()

    if hint_popup and hint_popup.bufnr and vim.api.nvim_buf_is_valid(hint_popup.bufnr) then
      vim.bo[hint_popup.bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(hint_popup.bufnr, 0, -1, false, { hint_text() })
      vim.bo[hint_popup.bufnr].modifiable = false
      vim.api.nvim_buf_add_highlight(hint_popup.bufnr, -1, "ThemeBrowserSubtle", 0, 0, -1)
    end
  end
  local function sync_selection_from_cursor()
    if syncing_cursor or not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
      return
    end

    local row = vim.api.nvim_win_get_cursor(popup.winid)[1]
    local candidate = scroll + (row - 3)
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

  local function apply_filter(new_query)
    query = new_query or ""
    if query == "" then
      items = vim.deepcopy(all_items)
    else
      local lowered = query:lower()
      items = {}
      for _, item in ipairs(all_items) do
        if item.sort_key:find(lowered, 1, true) then
          table.insert(items, item)
        end
      end
    end
    index = 1
    scroll = 1
    clamp_index()
    render()
  end

  local map_opts = { buffer = popup.bufnr, nowait = true, silent = true }

  local function map_keys(keys, fn)
    if type(keys) ~= "table" then
      return
    end
    for _, lhs in ipairs(keys) do
      vim.keymap.set("n", lhs, fn, map_opts)
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
      snapshot = state.build_state_snapshot and state.build_state_snapshot() or nil
      all_items = {}
      for _, entry in ipairs(entries) do
        table.insert(all_items, format_item(entry, snapshot))
      end
      table.sort(all_items, function(a, b)
        return a.sort_key < b.sort_key
      end)
      apply_filter(query)
    end)
  end)

  map_keys(keymaps.preview, function()
    if #items == 0 then
      return
    end
    local item = items[index]
    local status = theme_service.preview(item.entry.name, item.entry.variant, {
      notify = true,
      install_missing = true,
      on_preview_applied = function()
        snapshot = state.build_state_snapshot and state.build_state_snapshot() or nil
        all_items = {}
        for _, entry in ipairs(entries) do
          table.insert(all_items, format_item(entry, snapshot))
        end
        table.sort(all_items, function(a, b)
          return a.sort_key < b.sort_key
        end)
      end,
    })
    if status ~= 0 then
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
        vim.notify(string.format("Installed %s", item.entry.name), vim.log.levels.INFO)
        snapshot = state.build_state_snapshot and state.build_state_snapshot() or nil
        all_items = {}
        for _, entry in ipairs(entries) do
          table.insert(all_items, format_item(entry, snapshot))
        end
        table.sort(all_items, function(a, b)
          return a.sort_key < b.sort_key
        end)
        apply_filter(query)
      else
        vim.notify(string.format("Failed to install %s: %s", item.entry.name, err or "unknown error"), vim.log.levels.ERROR)
      end
    end)
  end)

  map_keys(keymaps.search, function()
    vim.ui.input({ prompt = "Theme search: ", default = query }, function(input)
      if input ~= nil then
        apply_filter(vim.trim(input))
      end
    end)
  end)

  map_keys(keymaps.clear_search, function()
    apply_filter("")
  end)

  map_keys(keymaps.copy_repo, function()
    if #items == 0 then
      return
    end
    local item = items[index]
    local repo = item.entry.repo
    if repo and repo ~= "" then
      local url = string.format("https://github.com/%s", repo)
      vim.fn.setreg("+", url)
      vim.notify(string.format("Copied: %s", url), vim.log.levels.INFO)
    else
      vim.notify("No repository URL available", vim.log.levels.WARN)
    end
  end)

  map_keys(keymaps.close, function()
    close_popups()
  end)

  popup:mount()
  picker_highlights.setup()

  hint_popup = Popup({
    enter = false,
    focusable = false,
    relative = "win",
    win = popup.winid,
    position = {
      row = vim.api.nvim_win_get_height(popup.winid),
      col = 0,
    },
    size = {
      width = vim.api.nvim_win_get_width(popup.winid),
      height = 1,
    },
    border = {
      style = "none",
    },
    win_options = {
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
    },
  })
  hint_popup:mount()

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

  vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
    buffer = popup.bufnr,
    once = true,
    callback = function()
      if hint_popup then
        close_popups()
      end
    end,
  })

  render()
end

return M
