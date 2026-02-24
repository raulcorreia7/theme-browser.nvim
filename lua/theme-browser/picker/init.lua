local M = {}

local has_telescope, telescope = pcall(require, "telescope")
local has_fzf, fzf_lua = pcall(require, "fzf-lua")

local registry = require("theme-browser.adapters.registry")
local state = require("theme-browser.persistence.state")
local theme_service = require("theme-browser.application.theme_service")
local options = require("theme-browser.config.options")
local preview_config = options.validate({}).preview_on_move or true

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

local function preview_entry(entry)
  theme_service.preview(entry.name, entry.variant, { notify = false })
end

local function use_entry(entry)
  theme_service.use(entry.name, entry.variant, { wait_install = true, notify = false })
end

-- Entry display formatting matching leetcode.nvim style
local function format_entry(theme_entry, snapshot)
  local variant = theme_entry.variant
  local status = entry_status(theme_entry, snapshot)
  
  -- Status icon (like leetcode's completion status)
  local status_icon = "○" -- not installed
  if status == "current" then
    status_icon = "✓"
  elseif status == "installed" then
    status_icon = "●"
  elseif status == "downloaded" then
    status_icon = "◐"
  end
  
  -- Background indicator (dark/light)
  local bg_icon = "◐"
  local bg = entry_background(theme_entry)
  if bg == "dark" then
    bg_icon = "◑"
  elseif bg == "light" then
    bg_icon = "◐"
  end
  
  -- Theme name and variant
  local name = theme_entry.name
  if variant and variant ~= theme_entry.colorscheme and variant ~= theme_entry.name then
    local prefix = theme_entry.name .. "-"
    local suffix = variant:sub(1, #prefix) == prefix and variant:sub(#prefix + 1) or variant
    name = string.format("[%s] %s", suffix, name)
  end
  
  -- Variant count indicator
  local variant_count = ""
  variant_count = ""
  
  return {
    status_icon = status_icon,
    bg_icon = bg_icon,
    name = name,
    variant_count = variant_count,
    ordinal = name:lower(),
    value = theme_entry,
    id = theme_entry.id,
  }
end

-- Telescope provider
function M.telescope_picker(opts)
  opts = opts or {}
  
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local entry_display = require("telescope.pickers.entry_display")
  
  -- Get all theme entries
  local entries = registry.list_entries()
  
  -- Filter entries if needed
  if opts.filter then
    entries = vim.tbl_filter(opts.filter, entries)
  end
  
  -- Format entries
  local snapshot = state.build_state_snapshot and state.build_state_snapshot() or nil
  local formatted = {}
  for _, entry in ipairs(entries) do
    table.insert(formatted, format_entry(entry, snapshot))
  end
  
  -- Create displayer
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 2 }, -- status icon
      { width = 2 }, -- bg icon
      { remaining = true }, -- name and variants
    },
  })
  
  -- Entry maker
  local function make_entry(entry)
    return {
      value = entry.value,
      display = function()
        return displayer({
          { entry.status_icon, "ThemeBrowserStatus" },
          { entry.bg_icon, entry_background(entry.value) == "light" and "ThemeBrowserLight" or "ThemeBrowserDark" },
          { entry.name .. " " .. entry.variant_count, "ThemeBrowserName" },
        })
      end,
      ordinal = entry.ordinal,
    }
  end
  
  -- Theme configuration
  local picker_theme = require("telescope.themes").get_dropdown({
    prompt_title = "Select Theme",
    results_title = "Themes",
    preview_title = "Preview",
    layout_config = {
      width = 0.8,
      height = 0.7,
    },
  })
  
  pickers.new(picker_theme, {
    prompt_title = "Select Theme",
    finder = finders.new_table({
      results = formatted,
      entry_maker = make_entry,
    }),
    sorter = conf.generic_sorter(picker_theme),
    attach_mappings = function(prompt_bufnr, map)
      local telescope_actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      
      telescope_actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if selection then
          use_entry(selection.value)
          telescope_actions.close(prompt_bufnr)
        end
      end)
      
      -- Preview on selection change
      telescope_actions.move_selection_next:enhance({
        post = function()
          local selection = action_state.get_selected_entry()
          if selection and preview_config then
            preview_entry(selection.value)
          end
        end,
      })
      
      telescope_actions.move_selection_previous:enhance({
        post = function()
          local selection = action_state.get_selected_entry()
          if selection and preview_config then
            preview_entry(selection.value)
          end
        end,
      })
      
      return true
    end,
  }):find()
end

-- FZF-Lua provider
function M.fzf_picker(opts)
  opts = opts or {}
  
  -- Get all theme entries
  local entries = registry.list_entries()
  
  -- Filter entries if needed
  if opts.filter then
    entries = vim.tbl_filter(opts.filter, entries)
  end
  
  -- Format entries for fzf
  local snapshot = state.build_state_snapshot and state.build_state_snapshot() or nil
  local formatted = {}
  local ids = {}
  for _, entry in ipairs(entries) do
    local formatted_entry = format_entry(entry, snapshot)
    table.insert(ids, formatted_entry.id)
    table.insert(formatted, string.format(
      "%s\t%s %s %-40s %s",
      formatted_entry.id,
      formatted_entry.status_icon,
      formatted_entry.bg_icon,
      formatted_entry.name,
      formatted_entry.variant_count
    ))
  end
  
  fzf_lua.fzf_exec(formatted, {
    prompt = "Theme> ",
    winopts = {
      height = 0.7,
      width = 0.8,
      preview = {
        hidden = "hidden",
        vertical = "down:45%",
      },
    },
    fzf_opts = {
      ["--delimiter"] = "\t",
      ["--nth"] = "2",
      ["--no-sort"] = "",
    },
    actions = {
      ["default"] = function(selected)
        local line = selected and selected[1]
        if not line then
          return
        end
        local id = line:match("^([^\t]+)")
        if not id then
          return
        end
        local entry = registry.get_entry(id)
        if entry then
          use_entry(entry)
        end
      end,
    },
  })
end

-- Main picker function - auto-detects available provider
function M.pick(opts)
  opts = opts or {}
  
  -- Try telescope first
  if has_telescope then
    return M.telescope_picker(opts)
  end
  
  -- Fall back to fzf-lua
  if has_fzf then
    return M.fzf_picker(opts)
  end
  
  -- Use native picker (nui-based, no external deps)
  local native = require("theme-browser.picker.native")
  return native.pick(opts)
end

return M
