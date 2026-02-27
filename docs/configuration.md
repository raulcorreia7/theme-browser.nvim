# Configuration Reference

## Registry

```lua
registry = {
  channel = "stable",  -- stable|latest
}
```

| Channel | Behavior |
|---------|----------|
| `stable` | Uses latest stable SemVer tag (`vX.Y.Z`) |
| `latest` | Uses weekly rolling release tags (`vX.Y.Z+YYYYMMDD`) |

## Package Manager

```lua
package_manager = {
  enabled = true,      -- Enable package manager integration
  mode = "manual",     -- Installation behavior
  provider = "auto",   -- Which package manager to use
}
```

### Mode

| Mode | Behavior |
|------|----------|
| `auto` | Automatically install missing themes on apply |
| `manual` | Install only when explicitly requested (`ThemeBrowser use`) |
| `installed_only` | Never download; only use installed plugins |

### Provider

| Provider | Description |
|----------|-------------|
| `auto` | Detect automatically (lazy.nvim if available) |
| `lazy` | Use lazy.nvim explicitly |
| `noop` | No package manager (manual path management) |

## Startup

```lua
startup = {
  enabled = true,              -- Enable startup theme restoration
  write_spec = true,           -- Generate managed lazy spec
  skip_if_already_active = true, -- Skip if colorscheme already loaded
}
```

## Cache

```lua
cache = {
  auto_cleanup = true,         -- Enable automatic cleanup
  cleanup_interval_days = 7,   -- Cleanup frequency
}
```

## UI

```lua
ui = {
  window_width = 0.6,          -- Gallery width (ratio)
  window_height = 0.5,         -- Gallery height (ratio)
  border = "rounded",          -- Window border style
  preview_on_move = true,      -- Preview on cursor move
}
```

## Keymaps

```lua
keymaps = {
  select = { "<CR>" },
  install = { "i" },
  copy_repo = { "Y" },
  open_repo = { "O" },
}
```

## Full Example

```lua
require("theme-browser").setup({
  auto_load = true,
  package_manager = {
    enabled = true,
    mode = "manual",
    provider = "auto",
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
  ui = {
    preview_on_move = true,
  },
})
```
