local M = {}

local function get_plugin_root()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  local absolute = vim.fn.fnamemodify(source, ":p")
  return vim.fn.fnamemodify(absolute, ":h:h:h:h")
end

local function file_exists(path)
  return type(path) == "string" and path ~= "" and vim.fn.filereadable(path) == 1
end

local function bundled_registry_path(root)
  return root .. "/lua/theme-browser/data/registry.json"
end

local function synced_registry_path()
  local ok, sync = pcall(require, "theme-browser.registry.sync")
  if ok and type(sync.get_synced_registry_path) == "function" then
    return sync.get_synced_registry_path()
  end
  return nil
end

local function candidate_paths(user_path)
  local root = get_plugin_root()
  local paths = {}

  if type(user_path) == "string" and user_path ~= "" then
    table.insert(paths, { source = "user", path = user_path })
  end

  local synced = synced_registry_path()
  if type(synced) == "string" and synced ~= "" then
    table.insert(paths, { source = "synced", path = synced })
  end

  table.insert(paths, { source = "bundled", path = bundled_registry_path(root) })

  return paths
end

---@param user_path string|nil
---@return table { path:string, source:string, candidates:table[] }
function M.resolve(user_path)
  local candidates = candidate_paths(user_path)

  for _, candidate in ipairs(candidates) do
    if file_exists(candidate.path) then
      return {
        path = candidate.path,
        source = candidate.source,
        candidates = candidates,
      }
    end
  end

  local fallback = candidates[#candidates]
  return {
    path = fallback.path,
    source = "missing",
    candidates = candidates,
  }
end

return M
