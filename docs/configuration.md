# Configuration Reference

This is the authoritative option reference for `require("theme-browser").setup()`.

Defaults are defined in `lua/theme-browser/config/defaults.lua`.

## Top-Level Options

| Option | Default | Notes |
|--------|---------|-------|
| `registry_path` | resolved at startup | Usually do not override; registry resolver picks the active channel path |
| `cache_dir` | `stdpath("cache") .. "/theme-browser"` | Theme cache root |
| `local_repo_sources` | `{}` | Extra local directories or repo roots to search first |
| `auto_load` | `false` | Restore the persisted theme on startup |
| `log_level` | `"info"` | `error`, `warn`, `info`, or `debug` |

## Registry

```lua
registry = {
  channel = "stable",
}
```

| Channel | Behavior |
|---------|----------|
| `stable` | Use the latest SemVer tag (`vX.Y.Z`) |
| `latest` | Use the rolling registry tag (`vX.Y.Z+YYYYMMDD`) |

## Local Repo Sources

```lua
local_repo_sources = {
  "~/projects",
  "~/themes",
}
```

- Accepts either a string or an array of strings.
- String values can be delimited with `,` or `;`.
- Startup spec generation also reads optional runtime inputs:
  - `vim.g.theme_browser_local_repo_sources`
  - `THEME_BROWSER_LOCAL_REPOS`
  - `THEME_BROWSER_LOCAL_THEME_SOURCES`

## Startup

```lua
startup = {
  enabled = true,
  write_spec = true,
  skip_if_already_active = true,
}
```

| Option | Default | Notes |
|--------|---------|-------|
| `enabled` | `true` | Enable startup restore logic |
| `write_spec` | `true` | Generate the managed lazy.nvim startup spec |
| `skip_if_already_active` | `true` | Avoid overwriting a theme that is already active |

## Cache

```lua
cache = {
  auto_cleanup = true,
  cleanup_interval_days = 7,
}
```

| Option | Default | Notes |
|--------|---------|-------|
| `auto_cleanup` | `true` | Enable periodic cache cleanup |
| `cleanup_interval_days` | `7` | Cleanup cadence in days |

## Package Manager

```lua
package_manager = {
  enabled = true,
  mode = "manual",
  provider = "auto",
}
```

### Mode

| Mode | Behavior |
|------|----------|
| `auto` | Automatically install missing themes when applying them |
| `manual` | Install on demand through plugin actions |
| `installed_only` | Never download themes |

### Provider

| Provider | Behavior |
|----------|----------|
| `auto` | Auto-detect the supported package manager |
| `lazy` | Use lazy.nvim explicitly |
| `noop` | Disable package manager integration |

## UI

```lua
ui = {
  window_width = 0.6,
  window_height = 0.5,
  border = "rounded",
  show_hints = true,
  show_breadcrumbs = true,
  preview_on_move = true,
}
```

| Option | Default |
|--------|---------|
| `window_width` | `0.6` |
| `window_height` | `0.5` |
| `border` | `"rounded"` |
| `show_hints` | `true` |
| `show_breadcrumbs` | `true` |
| `preview_on_move` | `true` |

## Status Display

```lua
status_display = {
  show_adapter = true,
  show_repo = true,
  show_cache_stats = true,
}
```

| Option | Default |
|--------|---------|
| `show_adapter` | `true` |
| `show_repo` | `true` |
| `show_cache_stats` | `true` |

## Keymaps

```lua
keymaps = {
  close = { "q", "<Esc>" },
  select = { "<CR>" },
  preview = { "p" },
  install = { "i" },
  set_main = { "m" },
  navigate_up = { "k", "<Up>", "<C-p>" },
  navigate_down = { "j", "<Down>", "<C-n>" },
  goto_top = { "gg" },
  goto_bottom = { "G" },
  scroll_up = { "<C-u>", "<PageUp>" },
  scroll_down = { "<C-d>", "<PageDown>" },
  search = { "/" },
  clear_search = { "c" },
  help = { "?" },
  copy_repo = { "Y" },
  open_repo = { "O" },
  visual = { "v" },
  visual_line = { "V" },
  yank = { "y" },
}
```

All keymap options accept either a string or an array of strings.

## Full Example

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
  cache = {
    auto_cleanup = true,
    cleanup_interval_days = 7,
  },
  package_manager = {
    enabled = true,
    mode = "manual",
    provider = "auto",
  },
  ui = {
    preview_on_move = true,
  },
})
```

## Related Docs

- `../README.md` - install, commands, and persistence overview
- `theme-source-strategy.md` - source precedence and cache tradeoffs
