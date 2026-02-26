local M = {}

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

local function apply_everforest(entry)
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

local HANDLERS = {
  everforest = apply_everforest,
}

function M.apply(entry)
  if type(entry) ~= "table" or type(entry.name) ~= "string" then
    return entry
  end

  local handler = HANDLERS[entry.name]
  if not handler then
    return entry
  end

  local cloned = vim.deepcopy(entry)
  local ok, result = pcall(handler, cloned)
  if not ok then
    return entry
  end

  return type(result) == "table" and result or cloned
end

return M
