local M = {}

-- Setup highlight groups for the picker UI
-- Uses linked groups to adapt to user's colorscheme (light/dark variants)
function M.setup()
  local highlights = {
    -- Status indicators - linked to semantic groups
    ThemeBrowserStatusCurrent = { link = "DiagnosticOk", default = true },
    ThemeBrowserStatusInstalled = { link = "String", default = true },
    ThemeBrowserStatusDownloaded = { link = "WarningMsg", default = true },
    ThemeBrowserStatusDefault = { link = "Comment", default = true },

    -- Background indicators - semantic colors (keep fixed for recognizability)
    ThemeBrowserDark = { fg = "#4444ff" },
    ThemeBrowserLight = { fg = "#ffcc00" },

    -- Theme names - linked to standard UI groups
    ThemeBrowserName = { link = "Normal", default = true },
    ThemeBrowserVariant = { link = "Comment", default = true },

    -- Preview window - linked to float/popup background
    ThemeBrowserPreview = { link = "NormalFloat", default = true },

    -- Selection - linked to standard selection highlight
    ThemeBrowserSelected = { link = "PmenuSel", default = true },
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
