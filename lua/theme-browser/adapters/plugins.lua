local M = {}

local handlers = {}

local function normalize_variant(value)
  if type(value) ~= "string" then
    return nil
  end
  return value:lower():gsub("_", "-")
end

local function ensure_strategy(entry)
  entry.meta = entry.meta or {}
  entry.meta.strategy = entry.meta.strategy or {}
  entry.meta.strategy.vim = entry.meta.strategy.vim or {}
end

local function everforest_handler(entry)
  local variant = normalize_variant(entry.variant)
  if not variant or variant == "" then
    return entry
  end

  ensure_strategy(entry)
  entry.colorscheme = "everforest"

  if variant:find("light", 1, true) then
    entry.meta.strategy.vim.o = entry.meta.strategy.vim.o or {}
    entry.meta.strategy.vim.o.background = "light"
    entry.meta.strategy.mode = "light"
  elseif variant:find("dark", 1, true) or variant:find("night", 1, true) then
    entry.meta.strategy.vim.o = entry.meta.strategy.vim.o or {}
    entry.meta.strategy.vim.o.background = "dark"
    entry.meta.strategy.mode = "dark"
  end

  if variant:find("soft", 1, true) then
    entry.meta.strategy.vim.g = entry.meta.strategy.vim.g or {}
    entry.meta.strategy.vim.g.everforest_background = "soft"
  elseif variant:find("hard", 1, true) then
    entry.meta.strategy.vim.g = entry.meta.strategy.vim.g or {}
    entry.meta.strategy.vim.g.everforest_background = "hard"
  elseif variant:find("medium", 1, true) then
    entry.meta.strategy.vim.g = entry.meta.strategy.vim.g or {}
    entry.meta.strategy.vim.g.everforest_background = "medium"
  end

  return entry
end

handlers.everforest = everforest_handler

function M.register(theme_name, handler)
  if type(theme_name) ~= "string" or theme_name == "" then
    return
  end
  if type(handler) ~= "function" then
    return
  end
  handlers[theme_name] = handler
end

function M.apply(entry)
  if type(entry) ~= "table" or type(entry.name) ~= "string" then
    return entry
  end

  local handler = handlers[entry.name]
  if not handler then
    return entry
  end

  local cloned = vim.deepcopy(entry)
  local ok, result = pcall(handler, cloned)
  if not ok then
    return entry
  end

  if type(result) == "table" then
    return result
  end
  return cloned
end

return M
