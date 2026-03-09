# theme-browser.nvim

Alpha Neovim theme gallery and loader. Browse, preview, apply, and persist
themes from the bundled registry.

## Quick Start

Install with `lazy.nvim` using a tagged release:

```lua
return {
  {
    "raulcorreia7/theme-browser.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = { "rktjmp/lush.nvim" },
    opts = {
      auto_load = true,
    },
  },
}
```

If you need a reproducible pin, use `tag = "vX.Y.Z"`.

Open the picker with `:ThemeBrowser`.

## Features

- Browse registry themes from inside Neovim.
- Preview themes before committing to them.
- Install, apply, and persist the active theme with one command.
- Restore the persisted theme on startup when `auto_load = true`.

## Commands

| Command | Description |
|---------|-------------|
| `:ThemeBrowser` | Open the theme picker |
| `:ThemeBrowser pick [query]` | Open the picker with an optional initial filter |
| `:ThemeBrowser focus` | Focus an existing picker window |
| `:ThemeBrowser use <name[:variant]> [variant]` | Install, apply, and persist a theme |
| `:ThemeBrowser status [name]` | Show status for the current or named theme |
| `:ThemeBrowser pm <enable|disable|toggle|status>` | Control package manager integration |
| `:ThemeBrowser browser <enable|disable|toggle|status>` | Control startup restore |
| `:ThemeBrowser <enable|disable|toggle>` | Shorthand for browser controls |
| `:ThemeBrowser registry <sync|clear>` | Registry controls compatibility alias |
| `:ThemeBrowser <sync|clear>` | Registry control shorthand |
| `:ThemeBrowser! sync` | Force registry sync |
| `:ThemeBrowser validate [output]` | Validate install, preview, and use flows |
| `:ThemeBrowser reset` | Clear plugin state, cache, and managed spec |
| `:ThemeBrowser help` | Show command help |

## Picker Keys

Default picker keys:

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate |
| `<CR>` | Apply theme and close |
| `m` | Apply theme and keep picker open |
| `p` | Preview selected theme |
| `i` | Install and mark theme |
| `/` | Start live search |
| `c` | Clear current search |
| `?` | Toggle help |
| `Y` | Copy selected repo URL |
| `O` | Open selected repo URL |
| `q` / `<Esc>` | Close picker |

## Persistence

With `startup.write_spec = true` (default), selecting a theme writes the managed
spec file at:

```text
~/.config/nvim/lua/plugins/theme-browser-selected.lua
```

That file gives startup restore an early, deterministic lazy.nvim entry point.

## Configuration

```lua
require("theme-browser").setup({
  auto_load = true,
  local_repo_sources = {
    "~/projects",
    "~/themes",
  },
  registry = {
    channel = "stable",
  },
  startup = {
    enabled = true,
    write_spec = true,
    skip_if_already_active = true,
  },
  package_manager = {
    enabled = true,
    mode = "manual",
    provider = "auto",
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

Key defaults:

| Option | Default | Description |
|--------|---------|-------------|
| `auto_load` | `false` | Restore the persisted theme on startup |
| `registry.channel` | `"stable"` | Use stable or rolling registry tags |
| `startup.write_spec` | `true` | Generate the managed lazy.nvim spec |
| `package_manager.mode` | `"manual"` | Install on demand unless you opt into `auto` |
| `ui.preview_on_move` | `true` | Preview installed themes while moving through the picker |

See `docs/configuration.md` for the full option reference.

## Files

| Path | Purpose |
|------|---------|
| `stdpath("data")/theme-browser/state.json` | Persisted plugin state |
| `stdpath("config")/lua/plugins/theme-browser-selected.lua` | Managed lazy.nvim startup spec |

## Development

From `packages/plugin`:

```bash
make verify
```

That runs setup checks, linting, format checks, smoke tests, and plugin tests.

## Related Docs

- `docs/configuration.md` - full configuration reference
- `docs/theme-source-strategy.md` - cache vs install behavior and tradeoffs
- `../registry/README.md` - registry package outputs and workflows
- `../../docs/release.md` - coordinated release process

## License

MIT
