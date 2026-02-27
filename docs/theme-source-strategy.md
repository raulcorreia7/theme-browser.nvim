# Theme Source Strategy

This document explains why preview/apply/install can feel counterintuitive, how the plugin currently resolves theme sources, and what tradeoffs come with each approach.

## Problem Statement

From a user perspective, it can seem redundant to:

1. download a theme for preview, then
2. write a managed spec file, and
3. let the package manager install/track it again.

The question is whether we should just use the downloaded repo directly.

## What the Plugin Does Today

### Preview and use/install flow

- `use()` and `preview()` first try to apply immediately.
- If apply fails, availability fallback runs:
  - package manager install path first (if provider is available), then
  - GitHub download fallback.
- `install()` is an alias for `use()`.

Code references:

- `lua/theme-browser/application/theme_service.lua`
  - immediate apply first: `apply_without_notify()` in `use()` and `preview()`
  - fallback chain: `ensure_theme_available_async()`
  - install alias: `M.install = M.use`

### Runtime source preference

When attaching a runtime path, the loader prefers:

1. cached repo path, then
2. lazy install path.

Code reference:

- `lua/theme-browser/runtime/loader.lua` (`attach_cached_runtime()`)

### Managed startup spec source resolution

The generated managed spec (`theme-browser-selected.lua`) is cache-aware and resolves source in this order:

1. `dir = cache_path` (downloaded repo)
2. `dir = stdpath("data") .. "/lazy/<repo>"` (lazy-installed repo)
3. fallback `[1] = "owner/repo"` (remote source)

Code reference:

- `lua/theme-browser/persistence/lazy_spec.lua` (`build_spec_content()`)

So, the plugin already supports the "use downloaded repo directly" idea.

## Why Write a Managed Spec At All

The managed spec is mostly about startup reliability, not just installation.

- It gives an early startup entry point for theme loading (`lazy = false`, high `priority`).
- Setup skips internal startup restore when a managed spec is present and enabled, to avoid duplicate restore paths.
- It persists a deterministic startup contract outside transient in-memory state.

Code references:

- `lua/theme-browser/persistence/lazy_spec.lua` (generated plugin spec content)
- `lua/theme-browser/init.lua` (`should_run_startup_restore()`)
- `lua/theme-browser/startup/persistence.lua` (`persist_applied_theme()`)

## Is This Different From Native lazy.nvim Behavior?

Using `dir = "/path/to/theme"` is valid and native in lazy.nvim plugin specs.

What differs is lifecycle semantics:

- repo specs (`"owner/repo"`) use lazy-managed clone/update/lock flows.
- local `dir` specs are treated as local sources, with different update and lockfile behavior.

External references:

- lazy.nvim spec docs: https://lazy.folke.io/spec
- lazy.nvim lockfile docs: https://lazy.folke.io/usage/lockfile

## Key Tradeoffs

### Cache-first (local dir as primary)

Pros:

- no second clone required to use immediately
- fast preview/apply path
- works offline while cache exists

Cons:

- update/freshness policy must be handled by theme-browser (or user workflow)
- cache cleanup can remove active source unless guarded
- lockfile semantics differ from fully managed lazy repo sources

### Package-manager-first (repo as primary)

Pros:

- standard lazy lifecycle (install/update/restore expectations)
- easier reproducibility in typical lazy workflows

Cons:

- can duplicate downloaded content (cache + lazy install)
- slower first use when not already installed

## Implications for "Who Owns Updates"

If startup/runtime uses local cache dirs as the source of truth, updates are effectively owned by theme-browser policy (or explicit user actions), not by lazy's normal remote-managed flow.

If startup/runtime uses lazy-managed repo specs as source of truth, lazy's normal update/lock workflows remain primary.

Current behavior is intentionally hybrid.

## Recommended Direction

Keep hybrid behavior, but make the model explicit:

1. use cache-first for fast preview/apply,
2. keep managed spec cache-aware with fallback (already implemented),
3. optionally provide explicit "promote to managed install" semantics for users who want lazy-native update expectations.

## Related Config Knobs

- `startup.write_spec` controls whether managed spec is written.
- `cache.auto_cleanup` and `cache.cleanup_interval_days` affect cache retention.
- `package_manager.mode` controls normal install behavior (`auto`, `manual`, `installed_only`).

Defaults:

- `startup.write_spec = true`
- `cache.auto_cleanup = true`
- `package_manager.mode = "manual"`

Code reference:

- `lua/theme-browser/config/defaults.lua`
