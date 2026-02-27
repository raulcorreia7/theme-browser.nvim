local M = {}

-- Setup highlight groups for the picker UI
-- Uses linked groups to adapt to user's colorscheme (light/dark variants)
function M.setup()
  local highlights = {
    -- Status indicators - linked to semantic groups
    ThemeBrowserStatusCurrent = { link = "DiagnosticOk", default = true },
    ThemeBrowserStatusPreviewing = { link = "DiagnosticHint", default = true },
    ThemeBrowserStatusPreviewed = { link = "DiagnosticInfo", default = true },
    ThemeBrowserStatusInstalled = { link = "String", default = true },
    ThemeBrowserStatusDownloaded = { link = "WarningMsg", default = true },
    ThemeBrowserStatusDefault = { link = "Comment", default = true },

    -- Background indicators - linked for cross-theme legibility
    ThemeBrowserDark = { link = "DiagnosticInfo", default = true },
    ThemeBrowserLight = { link = "WarningMsg", default = true },

    -- Theme names - linked to standard UI groups
    ThemeBrowserName = { link = "Normal", default = true },
    ThemeBrowserSeparator = { link = "NonText", default = true },
    ThemeBrowserVariant = { link = "Comment", default = true },
    ThemeBrowserVariantDefault = { link = "NonText", default = true },

    -- Preview window - linked to float/popup background
    ThemeBrowserPreview = { link = "NormalFloat", default = true },

    -- Selection - keep subtle and consistent across schemes
    ThemeBrowserSelected = { link = "CursorLine", default = true },
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
