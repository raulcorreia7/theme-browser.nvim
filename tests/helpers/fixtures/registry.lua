local M = {}

M.minimal = {
  {
    name = "test-theme",
    colorscheme = "test-theme",
    repo = "test/theme.nvim",
    strategy = "colorscheme",
  },
  {
    name = "tokyonight",
    colorscheme = "tokyonight",
    repo = "folke/tokyonight.nvim",
    strategy = "setup",
    module = "tokyonight",
    variants = {
      { name = "tokyonight-night", colorscheme = "tokyonight-night", mode = "dark" },
      { name = "tokyonight-storm", colorscheme = "tokyonight-storm", mode = "dark" },
      { name = "tokyonight-moon", colorscheme = "tokyonight-moon", mode = "dark" },
      { name = "tokyonight-day", colorscheme = "tokyonight-day", mode = "light" },
    },
  },
  {
    name = "catppuccin",
    colorscheme = "catppuccin",
    repo = "catppuccin/nvim",
    strategy = "setup",
    module = "catppuccin",
    variants = {
      { name = "catppuccin-latte", colorscheme = "catppuccin-latte", mode = "light" },
      { name = "catppuccin-frappe", colorscheme = "catppuccin-frappe", mode = "dark" },
      { name = "catppuccin-macchiato", colorscheme = "catppuccin-macchiato", mode = "dark" },
      { name = "catppuccin-mocha", colorscheme = "catppuccin-mocha", mode = "dark" },
    },
  },
}

M.standard = vim.list_extend(vim.deepcopy(M.minimal), {
  {
    name = "kanagawa",
    colorscheme = "kanagawa",
    repo = "rebelot/kanagawa.nvim",
    strategy = "load",
    variants = {
      { name = "kanagawa-wave", colorscheme = "kanagawa-wave", mode = "dark" },
      { name = "kanagawa-dragon", colorscheme = "kanagawa-dragon", mode = "dark" },
      { name = "kanagawa-lotus", colorscheme = "kanagawa-lotus", mode = "light" },
    },
  },
  {
    name = "gruvbox",
    colorscheme = "gruvbox",
    repo = "morhetz/gruvbox",
    strategy = "colorscheme",
  },
  {
    name = "default",
    colorscheme = "default",
    source = "neovim",
  },
})

M.no_variants = {
  {
    name = "simple-theme",
    colorscheme = "simple-theme",
    repo = "user/simple-theme",
    strategy = "colorscheme",
  },
}

M.builtin_only = {
  { name = "default", colorscheme = "default", source = "neovim" },
  { name = "blue", colorscheme = "blue", source = "neovim" },
}

M.single_variant = {
  {
    name = "one-variant",
    colorscheme = "one-variant",
    repo = "user/one-variant",
    strategy = "setup",
    variants = {
      { name = "one-variant-dark", colorscheme = "one-variant-dark", mode = "dark" },
    },
  },
}

function M.write_fixture(name, fixture_key)
  local content = M[fixture_key] or M.minimal
  local path = vim.fn.tempname() .. "-" .. name .. ".json"
  vim.fn.writefile({ vim.json.encode(content) }, path)
  return path
end

return M
