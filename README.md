# theme-browser.nvim

> ⚠️ **ALPHA - NOT FOR PRODUCTION USE**
> 
> This plugin is under active development. APIs, commands, and behavior may change without notice.
> Breaking changes may occur between commits. Use at your own risk.

`theme-browser.nvim` is a Neovim theme gallery and loader.

It lets you browse curated themes, preview them instantly, and persist your selected theme across restarts.

## What it does

- Shows a compact theme browser modal inside Neovim.
- Lists curated themes (including variants).
- Installs, applies, and persists themes from one workflow.
- Persists selected theme and restores it on startup.
- Supports different theme loading styles through adapters.

## Why use it

- You can try themes quickly without manually wiring every plugin.
- You get one consistent workflow for colorscheme-only themes and setup-based themes.
- You keep a single source of truth for your current theme.

## How it works

1. Theme Browser reads the curated index.
2. You preview/apply a theme from the gallery.
3. If theme files are missing, `ThemeBrowserUse` generates a managed spec and installs with lazy.nvim.
4. Applying a theme persists selection to state.
6. Cache cleanup runs automatically every week by default.
7. On startup, it restores your persisted theme using the managed startup spec.

Default mode is `manual` with package-manager integration enabled.

Registry loading prefers your configured path when readable, then falls back to the bundled registry shipped with the plugin.

`startup.write_spec` defaults to `true` so startup uses a managed theme spec.

## Requirements

- Neovim >= 0.8

Recommended:

- `rktjmp/lush.nvim`
- `nvim-lua/plenary.nvim` (test/runtime helpers)

## Setup

### Lazy/LazyVim

```lua
-- ~/.config/nvim/lua/plugins/theme-browser.lua
return {
  {
    "rcorreia/theme-browser.nvim",
    event = "VeryLazy",
    dependencies = {
      "rktjmp/lush.nvim",
    },
    opts = {
      auto_load = false,
      package_manager = {
        enabled = true,
        mode = "manual",
      },
    },
  },
}
```

### Local development setup

```lua
-- ~/.config/nvim/lua/plugins/theme-browser.lua
return {
  {
    dir = "/home/rcorreia/projects/theme-browser-monorepo/theme-browser.nvim",
    name = "theme-browser.nvim",
    event = "VeryLazy",
    dependencies = {
      "rktjmp/lush.nvim",
    },
    opts = {
      auto_load = false,
      startup = {
        enabled = true,
        write_spec = true,
      },
      package_manager = {
        enabled = true,
        mode = "manual",
      },
    },
    config = function(_, opts)
      require("theme-browser").setup(opts)
    end,
  },
}
```

## Commands

- `:ThemeBrowser [query]` open gallery
- `:ThemeBrowserUse <name> [variant]` install/load/apply + persist
- `:ThemeBrowserUse <name:variant>` also supported
- `:ThemeBrowserStatus [name]` show status
- `:ThemeBrowserPackageManager <enable|disable|toggle|status>` control package manager integration
- `:ThemeBrowserReset` reset state + cache + managed spec
- `:ThemeBrowserHelp` show command help

## Gallery keys

- `j/k`, `<C-n>/<C-p>`, `<C-j>/<C-k>` move
- `/`, `n`, `N` search and jump
- `<CR>` install/load/apply + persist
- `p` preview
- `i` install/load/apply + persist
- `<Esc>` clear search first, close when search context is clear
- Shortcuts are shown in the window top bar (winbar), not inside buffer text

## Persistence files

- State file: `stdpath("data")/theme-browser/state.json`
- Managed spec file: `~/.config/nvim/lua/plugins/theme-browser-selected.lua`

## Configuration

```lua
require("theme-browser").setup({
  auto_load = false,
  package_manager = {
    enabled = true,
    mode = "manual", -- auto | manual | plugin_only
    provider = "auto", -- auto | lazy | noop
  },
  startup = {
    enabled = true,
    write_spec = true,
    skip_if_already_active = true,
  },
  cache = {
    auto_cleanup = true,
    cleanup_interval_days = 7,
  },
  ui = {
    window_width = 0.6,
    window_height = 0.5,
    border = "rounded",
    preview_on_move = true, -- preview installed/cached themes on cursor move
  },
  keymaps = {
  },
})
```

## Testing

`ThemeBrowserUse` is the canonical flow and installs through `lazy.nvim` when needed.

```bash
make verify
```

CI runs `make verify` with lint/format/test checks on Ubuntu and macOS.
In CI (`CI=true`), tests fail when `plenary.nvim` is unavailable instead of being skipped.

## License

MIT
