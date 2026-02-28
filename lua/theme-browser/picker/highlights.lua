local M = {}

local function has_group(name)
  return type(name) == "string" and name ~= "" and vim.fn.hlexists(name) == 1
end

local function link_or(primary, fallback)
  if has_group(primary) then
    return { link = primary, default = true }
  end
  return { link = fallback, default = true }
end

-- Setup highlight groups for the picker UI.
function M.setup()
  local highlights = {
    ThemeBrowserStatusCurrent = link_or("DiagnosticOk", "DiffAdded"),
    ThemeBrowserStatusPreviewing = link_or("DiagnosticHint", "DiagnosticInfo"),
    ThemeBrowserStatusPreviewed = link_or("DiagnosticInfo", "Identifier"),
    ThemeBrowserStatusInstalled = link_or("String", "Function"),
    ThemeBrowserStatusDownloaded = link_or("WarningMsg", "Constant"),
    ThemeBrowserStatusDefault = link_or("Comment", "Comment"),
    ThemeBrowserDark = link_or("DiagnosticInfo", "Type"),
    ThemeBrowserLight = link_or("WarningMsg", "Type"),
    ThemeBrowserName = link_or("NormalFloat", "Normal"),
    ThemeBrowserSeparator = link_or("NonText", "Comment"),
    ThemeBrowserVariant = link_or("Comment", "Comment"),
    ThemeBrowserVariantDefault = link_or("NonText", "Comment"),
    ThemeBrowserPreview = link_or("NormalFloat", "Normal"),
    ThemeBrowserVisual = link_or("Visual", "PmenuSel"),
    ThemeBrowserSelected = link_or("TelescopeSelection", "PmenuSel"),
    ThemeBrowserFuzzyMatch = link_or("TelescopeMatching", "Search"),
    ThemeBrowserPrompt = link_or("TelescopePromptNormal", "NormalFloat"),
    ThemeBrowserPromptIcon = link_or("TelescopePromptPrefix", "Special"),
    ThemeBrowserDivider = link_or("FloatBorder", "WinSeparator"),
    ThemeBrowserSubtle = link_or("Comment", "Comment"),
  }

  for name, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

-- Auto-setup on colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = M.setup,
})

return M
