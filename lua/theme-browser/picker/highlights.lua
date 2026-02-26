local M = {}

-- Setup highlight groups for the picker UI
function M.setup()
  local highlights = {
    -- Status indicators
    ThemeBrowserStatusCurrent = { fg = "#00ff00", bold = true },
    ThemeBrowserStatusInstalled = { fg = "#00aa00" },
    ThemeBrowserStatusDownloaded = { fg = "#ffaa00" },
    ThemeBrowserStatusDefault = { fg = "#666666" },

    -- Background indicators
    ThemeBrowserDark = { fg = "#4444ff" },
    ThemeBrowserLight = { fg = "#ffcc00" },

    -- Theme names
    ThemeBrowserName = { fg = "#ffffff" },
    ThemeBrowserVariant = { fg = "#888888" },

    -- Preview window
    ThemeBrowserPreview = { bg = "#1a1a1a" },

    -- Selection
    ThemeBrowserSelected = { bg = "#2a3f5f", bold = true },
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
