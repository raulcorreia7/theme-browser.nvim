local M = {}

local function format_theme_reference(theme)
  if type(theme) ~= "table" or type(theme.name) ~= "string" then
    return nil
  end

  if type(theme.variant) == "string" and theme.variant ~= "" then
    return string.format("%s:%s", theme.name, theme.variant)
  end

  return theme.name
end

local function format_readable_states(state, entry, snapshot)
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

local function parse_theme_arg(theme_arg)
  if type(theme_arg) ~= "string" or theme_arg == "" then
    return nil, nil
  end

  local name, variant = theme_arg:match("^([^:]+):(.+)$")
  if name then
    return name, variant
  end

  return theme_arg, nil
end

local function resolve_entry_by_arg(registry, theme_arg)
  local name, variant = parse_theme_arg(theme_arg)
  if not name then
    return nil
  end

  local entry = registry.resolve(name, variant)
  if entry then
    return entry
  end

  local theme = registry.get_theme(name)
  if not theme then
    return nil
  end

  return registry.resolve(theme.name, variant)
end

---@param theme_arg string|nil Theme name or name:variant
function M.show(theme_arg)
  local state = require("theme-browser.persistence.state")
  local registry = require("theme-browser.adapters.registry")
  local base = require("theme-browser.adapters.base")
  local snapshot = type(state.build_state_snapshot) == "function" and state.build_state_snapshot() or nil

  local current_theme = state.get_current_theme()
  local cache_stats = state.get_cache_stats()
  local pm_config = state.get_package_manager()

  local current_entry = nil
  if current_theme then
    current_entry = registry.resolve(current_theme.name, current_theme.variant)
  end

  local selected_entry = theme_arg and resolve_entry_by_arg(registry, theme_arg) or current_entry
  if theme_arg and not selected_entry then
    vim.notify(string.format("Theme '%s' not found", theme_arg), vim.log.levels.WARN)
    return
  end

  local lines = {}
  table.insert(lines, "")
  table.insert(lines, "Theme Browser Status")
  table.insert(lines, "====================================")
  table.insert(lines, "")

  table.insert(lines, "Current Theme:")
  if current_theme then
    local variant = current_theme.variant or "default"
    table.insert(lines, string.format("  %s:%s", current_theme.name, variant))
  else
    table.insert(lines, "  (none)")
  end

  if current_entry then
    table.insert(lines, string.format("  States: %s", format_readable_states(state, current_entry, snapshot)))
  else
    table.insert(lines, "  States: (unresolved)")
  end

  table.insert(lines, "")
  table.insert(lines, "Selected Entry:")
  if selected_entry then
    local variant = selected_entry.variant or "default"
    table.insert(lines, string.format("  %s:%s", selected_entry.name, variant))
    table.insert(lines, string.format("  Repo:   %s", selected_entry.repo))
    table.insert(lines, string.format("  States: %s", format_readable_states(state, selected_entry, snapshot)))
  else
    table.insert(lines, "  (none)")
  end

  table.insert(lines, "")
  table.insert(lines, "State Legend:")
  table.insert(lines, "  Current = currently applied")
  table.insert(lines, "  Installed = managed by Lazy/config")
  table.insert(lines, "  Downloaded = present in local cache")
  table.insert(lines, "  Marked = queued for install")

  table.insert(lines, "")
  table.insert(lines, "Marked for Install:")
  local marked = state.get_marked_theme()
  local marked_label = format_theme_reference(marked)
  if marked_label then
    table.insert(lines, string.format("  %s", marked_label))
  else
    table.insert(lines, "  (none)")
  end

  table.insert(lines, "")
  table.insert(lines, "Cache Statistics:")
  table.insert(lines, string.format("  Hits:     %d", cache_stats.hits))
  table.insert(lines, string.format("  Misses:   %d", cache_stats.misses))

  if cache_stats.hits + cache_stats.misses > 0 then
    local hit_rate = (cache_stats.hits / (cache_stats.hits + cache_stats.misses)) * 100
    table.insert(lines, string.format("  Hit Rate: %.1f%%", hit_rate))
  end

  table.insert(lines, "")
  table.insert(lines, "Package Manager:")
  table.insert(lines, string.format("  Detected: %s", base.has_package_manager() and "Yes" or "No"))
  table.insert(lines, string.format("  Enabled:  %s", pm_config.enabled and "Yes" or "No"))
  table.insert(lines, string.format("  Mode:     %s", pm_config.mode))

  print(table.concat(lines, "\n"))
end

return M
