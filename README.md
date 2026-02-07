# theme-browser.nvim

`theme-browser.nvim` is a Neovim theme gallery and loader.

It lets you browse curated themes, preview them instantly, and persist your selected theme across restarts.

## What it does

- Shows a compact theme browser modal inside Neovim.
- Lists curated themes (including variants).
- Previews themes dynamically (download + apply when needed).
- Persists selected theme and restores it on startup.
- Supports different theme loading styles through adapters.

## Why use it

- You can try themes quickly without manually wiring every plugin.
- You get one consistent workflow for colorscheme-only themes and setup-based themes.
- You keep a single source of truth for your current theme.

## How it works

1. Theme Browser reads the curated index.
2. You preview/apply a theme from the gallery.
3. If theme files are missing, it performs a shallow download and loads from cache.
4. Installing a theme marks it for install and starts a background prefetch.
5. Applying a theme persists selection to state and updates the managed startup spec.
6. Cache cleanup runs automatically every week by default.
7. On startup, it restores your persisted theme using the managed startup spec.

Default mode is `plugin_only` (Theme Browser manages loading directly, without requiring package-manager install).

By default, a successful apply also updates `theme-browser-selected.lua` (including in `plugin_only` mode) to keep startup flicker-safe. To opt out, set `startup.write_spec = false`.

## Requirements

- Neovim >= 0.8
- `git`

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
      auto_load = true,
      show_preview = false,
      package_manager = {
        enabled = false,
        mode = "plugin_only",
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
    dir = "/home/rcorreia/projects/theme-browser.nvim",
    name = "theme-browser.nvim",
    event = "VeryLazy",
    dependencies = {
      "rktjmp/lush.nvim",
    },
    opts = {
      auto_load = true,
      show_preview = false,
      package_manager = {
        enabled = false,
        mode = "plugin_only",
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
- `:ThemeBrowserTheme <name> [variant]` apply + persist
- `:ThemeBrowserPreview <name> [variant]` preview (non-persistent)
- `:ThemeBrowserClean` clean cache now
- `:ThemeBrowserInstall[!] <name> [variant]` write managed spec, install via lazy in-session, and apply now (`!` waits)
- `:ThemeBrowserUninstall` remove managed spec
- `:ThemeBrowserStatus [name]` show status
- `:ThemeBrowserReset` reset state + cache + managed spec
- `:ThemeBrowserFocus` refocus gallery
- `:ThemeBrowserHelp` show command help

## Gallery keys

- `j/k`, `<C-n>/<C-p>`, `<C-j>/<C-k>` move
- `/`, `n`, `N` search and jump
- `<CR>` apply + persist
- `p` preview
- `i` install
- `m` mark
- `<Esc>` clear search first, close when search context is clear

## Persistence files

- State file: `stdpath("data")/theme-browser/state.json`
- Managed spec file: `~/.config/nvim/lua/plugins/theme-browser-selected.lua`

## Configuration

```lua
require("theme-browser").setup({
  auto_load = true,
  show_preview = false,
  package_manager = {
    enabled = false,
    mode = "plugin_only", -- auto | manual | plugin_only
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
    preview_on_move = false, -- preview installed/cached themes on cursor move
  },
  keymaps = {
  },
})
```

## Testing

`ThemeBrowserInstall` attempts an in-session install through `lazy.nvim` when available, so a restart is not required for installation.

```bash
make verify
```

CI runs `make verify` on Ubuntu with Neovim stable + nightly.
In CI (`CI=true`), tests fail when `plenary.nvim` is unavailable instead of being skipped.

## License

MIT
