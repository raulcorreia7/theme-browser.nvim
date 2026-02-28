# theme-browser.nvim

> ⚠️ **ALPHA** - Under active development. APIs may change.

Neovim theme gallery and loader. Browse, preview, apply, and persist themes.

## Quick Start

Install with lazy.nvim using the latest tagged release (instead of `main`/HEAD):

```lua
-- ~/.config/nvim/lua/plugins/theme-browser.lua
return {
  {
    "raulcorreia7/theme-browser.nvim",
    version = "*", -- latest stable tag
    event = "VeryLazy",
    dependencies = { "rktjmp/lush.nvim" },
    opts = {
      auto_load = true,
    },
  },
}
```

If you want an exact pin for reproducible setups, use `tag = "vX.Y.Z"`.

Open picker: `:ThemeBrowser`

### Persistence

With `startup.write_spec = true` (default), selecting a theme generates:
```
~/.config/nvim/lua/plugins/theme-browser-selected.lua
```

This managed spec ensures your theme loads on startup without manual lazy.nvim specs.

## Commands

| Command | Description |
|---------|-------------|
| `:ThemeBrowser` | Open theme gallery |
| `:ThemeBrowser pick [query]` | Open gallery with optional initial filter |
| `:ThemeBrowser focus` | Focus an already-open picker |
| `:ThemeBrowser use <name[:variant]> [variant]` | Install, apply, persist theme |
| `:ThemeBrowser status [name]` | Show theme status |
| `:ThemeBrowser pm <enable\|disable\|toggle\|status>` | Package manager controls |
| `:ThemeBrowser <enable\|disable\|toggle>` | Startup restore controls (inline) |
| `:ThemeBrowser browser <enable\|disable\|toggle\|status>` | Startup restore controls |
| `:ThemeBrowser <sync\|clear>` | Registry sync/clear (inline) |
| `:ThemeBrowser! sync` | Force registry sync |
| `:ThemeBrowser validate [output]` | Validate theme can load |
| `:ThemeBrowser reset` | Clear state, cache, managed spec |
| `:ThemeBrowser help` | Show help |

`registry <sync|clear>` remains available as a compatibility alias.

## Picker Keys

| Key | Action |
|-----|--------|
| `j/k` | Navigate |
| `?` | Toggle help |
| `/` | Start live fuzzy search |
| `<CR>` | Apply theme |
| `i` | Install + mark for later |
| `Y` | Copy selected theme repo URL |
| `O` | Open selected theme repo URL |
| `<Esc>` | Close |

## How It Works

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Picker    │───▶│ ThemeService │───▶│   Adapters  │
│ (vim.ui)    │    │ (orchestr.)  │    │ (loaders)   │
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
  local_repo_sources = {
    "~/projects",
    "~/themes",
  },
  package_manager = {
    enabled = true,
    mode = "manual",  -- auto|manual|installed_only
    provider = "auto", -- auto|lazy|noop
  },
  registry = {
    channel = "stable", -- stable|latest
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
| `registry.channel` | `"stable"` | Registry channel: `stable` (SemVer tags) or `latest` (weekly `vX.Y.Z+YYYYMMDD`) |
| `local_repo_sources` | `{}` | Array of local directories/repo roots used when resolving theme sources |
| `startup.write_spec` | `true` | Generate managed lazy spec for persistence |
| `ui.preview_on_move` | `true` | Preview installed themes on cursor move |

See [docs/configuration.md](docs/configuration.md) for full reference.

## Files

| Path | Purpose |
|------|---------|
| `stdpath("data")/theme-browser/state.json` | Persisted state |
| `stdpath("config")/lua/plugins/theme-browser-selected.lua` | Managed lazy spec |

## Theme Compatibility

- Setup-based themes with variants are supported across common option keys:
  `theme`, `palette`, `style`, `colorscheme`, `variant`, `flavour`, `flavor`
- Variant metadata from the registry is preserved so loader strategy/module hints work per entry
- Themes that modify external user config files outside Neovim are excluded at the registry level

## Architecture

See [docs/architecture.md](docs/architecture.md) for layer details.
See [docs/theme-source-strategy.md](docs/theme-source-strategy.md) for cache vs install behavior and tradeoffs.

## Testing

```bash
make verify
```

## Release Process

- Keep `CHANGELOG.md` updated before tagging.
- Tags follow SemVer: `vX.Y.Z`.
- Release workflow uses `CHANGELOG.md` section for release notes when available.
- Release workflow publishes `themes.json` and `manifest.json` assets.
- Release workflow validates uploaded assets (exists and non-zero size).

## Related

- [theme-browser-registry](https://github.com/raulcorreia7/theme-browser-registry) — Theme registry indexer

## License

MIT
