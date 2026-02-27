local M = {}

local nerd_font_detected = nil

function M.has_nerd_font()
  if nerd_font_detected ~= nil then
    return nerd_font_detected
  end

  local g = vim.g
  if g.have_nerd_font == true or g.have_nerd_font == 1 or g.NerdFont == true then
    nerd_font_detected = true
    return true
  end

  local guifont = vim.o.guifont
  if type(guifont) == "string" and guifont:lower():find("nerd", 1, true) then
    nerd_font_detected = true
    return true
  end

  nerd_font_detected = false
  return false
end

local STATE_ICONS = {
  current = "●",
  installed = "◆",
  downloaded = "↓",
  previewing = "◉",
  previewed = "◈",
  dark = "◐",
  light = "◑",
  available = "○",
  marked = "★",
}

if M.has_nerd_font() then
  STATE_ICONS.current = ""
  STATE_ICONS.installed = ""
  STATE_ICONS.downloaded = ""
  STATE_ICONS.previewing = ""
  STATE_ICONS.previewed = ""
  STATE_ICONS.dark = ""
  STATE_ICONS.light = ""
  STATE_ICONS.available = ""
  STATE_ICONS.marked = ""
end

M.STATE_ICONS = STATE_ICONS

return M
