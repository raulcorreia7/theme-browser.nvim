local M = {}
local log = require("theme-browser.util.log")

local function get_spec_file()
  return vim.fn.stdpath("config") .. "/lua/plugins/selected-theme.lua"
end

local function ensure_parent_dir(path)
  local parent = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(parent) == 0 then
    vim.fn.mkdir(parent, "p")
  end
end

local function build_spec_content(theme_repo, colorscheme)
  return string.format(
    [[
return {
  {
    "%s",
    dependencies = { "rktjmp/lush.nvim" },
    lazy = false,
    priority = 1000,
    config = function()
      if vim.g.colors_name == "%s" then
        return
      end

      local ok_base, base = pcall(require, "theme-browser.adapters.base")
      local ok_state, state = pcall(require, "theme-browser.persistence.state")
      local current = ok_state and state.get_current_theme and state.get_current_theme() or nil
      if ok_base and current and current.name then
        local result = base.load_theme(current.name, current.variant, { notify = false, persist_startup = false })
        if result and result.ok then
          return
        end
      end
      pcall(vim.cmd.colorscheme, "%s")
    end,
  },
}
]],
    theme_repo,
    colorscheme,
    colorscheme
  )
end

---Generate LazyVim spec file
---@param theme_name string Theme name
---@param variant string|nil Theme variant
---@param opts table|nil { notify:boolean|nil, update_state:boolean|nil }
function M.generate_spec(theme_name, variant, opts)
  opts = opts or {}
  local notify = opts.notify
  if notify == nil then
    notify = true
  end
  local update_state = opts.update_state
  if update_state == nil then
    update_state = true
  end

  local registry = require("theme-browser.adapters.registry")
  local entry = registry.resolve(theme_name, variant)

  if not entry then
    log.warn(string.format("Theme '%s' not found in registry", theme_name))
    return nil
  end

  local spec_file = get_spec_file()
  ensure_parent_dir(spec_file)

  local spec_content = build_spec_content(entry.repo, entry.colorscheme or entry.name)
  local file = io.open(spec_file, "w")
  if not file then
    log.error(string.format("Failed to write spec to: %s", spec_file))
    return nil
  end

  file:write(spec_content)
  file:close()

  if update_state then
    local state = require("theme-browser.persistence.state")
    state.set_current_theme(entry.name, entry.variant)
  end

  if notify then
    log.info(string.format("LazyVim spec written to: %s", spec_file))
  end
  return spec_file
end

---Detect if lazy.nvim is available
---@return boolean
function M.has_lazy()
  return package.loaded["lazy"] ~= nil or pcall(require, "lazy")
end

---Get current LazyVim spec state
---@return table|nil current spec theme
function M.get_current_spec()
  local spec_file = get_spec_file()
  if vim.fn.filereadable(spec_file) == 0 then
    return nil
  end

  local lines = vim.fn.readfile(spec_file)
  local content = table.concat(lines, "\n")
  local repo = content:match('"([^"]+)"')
  if not repo then
    return nil
  end

  local registry = require("theme-browser.adapters.registry")
  local themes = registry.list_themes()
  for _, theme in ipairs(themes) do
    if theme.repo == repo then
      return theme
    end
  end

  return nil
end

---Remove LazyVim spec
---@param opts table|nil {notify:boolean|nil}
function M.remove_spec(opts)
  opts = opts or {}
  local notify = opts.notify
  if notify == nil then
    notify = true
  end

  local spec_file = get_spec_file()
  if vim.fn.filereadable(spec_file) == 1 then
    vim.fn.delete(spec_file)
    if notify then
      log.info("LazyVim spec removed")
    end
  end
end

return M
