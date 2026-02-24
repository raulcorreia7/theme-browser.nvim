local M = {}

local groups = {
  ThemeBrowserHeader = { link = "Title", default = true },
  ThemeBrowserSubtle = { link = "Comment", default = true },
  ThemeBrowserDivider = { link = "WinSeparator", default = true },
  ThemeBrowserTableHeader = { link = "Identifier", default = true },
  ThemeBrowserRowSelected = { link = "PmenuSel", default = true },
  ThemeBrowserStateCurrent = { link = "DiagnosticOk", default = true },
  ThemeBrowserStateInstalled = { link = "Function", default = true },
  ThemeBrowserStateCached = { link = "Type", default = true },
  ThemeBrowserStateMarked = { link = "WarningMsg", default = true },
  ThemeBrowserStateAvailable = { link = "Comment", default = true },
}

function M.apply()
  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
end

return M
