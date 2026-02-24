# Architecture

## Layers

```
┌─────────────────────────────────────────────────────────┐
│                      Interface                           │
│  Commands (init.lua)  │  Gallery UI (picker.lua)        │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────┴─────────────────────────────────┐
│                    Application                           │
│  ThemeService  │  Startup/Restore  │  Preview Manager   │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────┴─────────────────────────────────┐
│                      Adapters                            │
│  Registry  │  Base (loader)  │  Factory  │  Plugins     │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────┴─────────────────────────────────┐
│                   Infrastructure                         │
│  State (persistence)  │  Downloader  │  Runtime/Loader  │
└─────────────────────────────────────────────────────────┘
```

## Components

### Interface Layer
- **init.lua** - Command registration, setup, entry point
- **picker.lua** - Gallery UI with search, navigation, preview

### Application Layer
- **ThemeService** - Orchestrates install → load → persist workflow
- **Startup/Restore** - Restores persisted theme on startup
- **Preview Manager** - Temporary theme preview without persisting

### Adapters Layer
- **Registry** - Theme index, lookup, resolution
- **Base** - Theme loading (colorscheme vs setup-based)
- **Factory** - Creates appropriate loader per theme type
- **Plugins** - Package manager integration (lazy.nvim)

### Infrastructure Layer
- **State** - Persisted JSON state (current theme, history, flags)
- **Downloader** - GitHub repo caching for preview
- **Runtime/Loader** - Runtimepath management for cached themes

## Data Flow

```
User selects theme in Gallery
        │
        ▼
  ThemeService.use()
        │
        ├──▶ Registry.resolve(name, variant)
        │
        ├──▶ Base.load_theme()
        │         │
        │         ├── colorscheme (simple)
        │         └── require().setup() (complex)
        │
        └──▶ State.set_current_theme()
                  │
                  └──▶ Persist to state.json
```

## Startup Flow

```
Neovim starts
      │
      ▼
theme-browser.setup()
      │
      ├── Load state.json
      ├── Load registry
      └── if auto_load && browser_enabled:
              │
              ▼
        startup_restore.restore_current_theme()
              │
              └──▶ Load persisted theme
```

## Key Files

| Path | Responsibility |
|------|----------------|
| `lua/theme-browser/init.lua` | Setup, commands, coordination |
| `lua/theme-browser/picker.lua` | Gallery UI |
| `lua/theme-browser/application/theme_service.lua` | Theme orchestration |
| `lua/theme-browser/adapters/registry.lua` | Theme index/lookup |
| `lua/theme-browser/adapters/base.lua` | Theme loading |
| `lua/theme-browser/persistence/state.lua` | State management |
| `lua/theme-browser/persistence/lazy_spec.lua` | Managed spec generation |
