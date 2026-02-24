# theme-browser.nvim

> ⚠️ **ALPHA** - Under active development. APIs may change.

Neovim theme gallery and loader. Browse, preview, apply, and persist themes.

## Quick Start

```lua
-- ~/.config/nvim/lua/plugins/theme-browser.lua
return {
  {
    "rcorreia/theme-browser.nvim",
    event = "VeryLazy",
    dependencies = { "rktjmp/lush.nvim" },
    opts = {
      auto_load = true,
      package_manager = { enabled = true, mode = "manual" },
    },
  },
}
```

Open gallery: `:ThemeBrowser`

## Commands

| Command | Description |
|---------|-------------|
| `:ThemeBrowser` | Open theme gallery |
| `:ThemeBrowserUse <name> [variant]` | Install, apply, persist theme |
| `:ThemeBrowserDisable` | Disable theme loading on startup |
| `:ThemeBrowserEnable` | Re-enable and restore last theme |
| `:ThemeBrowserStatus [name]` | Show theme status |
| `:ThemeBrowserReset` | Clear state, cache, managed spec |

## Gallery Keys

| Key | Action |
|-----|--------|
| `j/k` | Navigate |
| `/` | Search |
| `<CR>` or `i` | Apply theme |
| `p` | Preview |
| `<Esc>` | Close |

## How It Works

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Gallery   │───▶│ ThemeService │───▶│   Adapters  │
│   (UI)      │    │ (orchestr.)  │    │ (loaders)   │
└─────────────┘    └──────────────┘    └─────────────┘
                           │
                           ▼
                   ┌──────────────┐
                   │    State     │
                   │ (persisted)  │
                   └──────────────┘
```

1. Browse themes from registry
2. Apply → installs (if needed) → loads → persists
3. On startup: restores persisted theme (if enabled)

## Configuration

```lua
require("theme-browser").setup({
  auto_load = true,
  package_manager = {
    enabled = true,
    mode = "manual",  -- auto|manual|installed_only
    provider = "auto", -- auto|lazy|noop
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
    preview_on_move = true,
  },
})
```

| Option | Default | Description |
|--------|---------|-------------|
| `auto_load` | `false` | Restore theme on startup |
| `package_manager.enabled` | `true` | Enable package manager integration |
| `package_manager.mode` | `"manual"` | `auto`: auto-install, `manual`: on-demand, `installed_only`: no downloads |
| `package_manager.provider` | `"auto"` | Package manager: `auto`, `lazy`, `noop` |
| `startup.write_spec` | `true` | Generate managed lazy spec for persistence |
| `ui.preview_on_move` | `true` | Preview installed themes on cursor move |

See [docs/configuration.md](docs/configuration.md) for full reference.

## Files

| Path | Purpose |
|------|---------|
| `stdpath("data")/theme-browser/state.json` | Persisted state |
| `stdpath("config")/lua/plugins/theme-browser-selected.lua` | Managed lazy spec |

## Architecture

See [docs/architecture.md](docs/architecture.md) for layer details.

## Testing

```bash
make verify
```

## License

MIT
