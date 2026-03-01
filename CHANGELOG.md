# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and this project follows SemVer.

## [0.4.3] - 2026-03-01

### Fixed

- Test runner properly handles plenary exit codes for CI compatibility.

## [0.4.2] - 2026-03-01

### Fixed

- Resolved luacheck warnings in picker/native.lua (comparison style, unused variable, duplicate function, empty branch).

## [0.4.1] - 2026-03-01

### Changed

- Updated bundled registry with latest theme data (304 themes, 399 variants).

## [0.4.0] - 2026-03-01

### Added

- Picker visual yank support for copying theme names in visual mode.
- ID-based sorting for consistent theme ordering across picker sessions.

## [0.3.5] - 2026-02-27

### Fixed
- Apply formatting updates required by the release workflow `make verify` gate.

## [0.3.4] - 2026-02-27

### Added
- Add configurable registry release channel selection with `registry.channel = "stable"|"latest"`.

### Changed
- Registry sync now resolves `latest` channel assets from weekly `vX.Y.Z+YYYYMMDD` release tags.
- Document registry channel behavior and configuration in README and configuration docs.

## [0.3.3] - 2026-02-27

### Fixed
- Accept top-level browser control commands (`:ThemeBrowser enable|disable|toggle`) without opening the picker.
- Simplify registry command UX with inline actions (`:ThemeBrowser sync|clear`, `:ThemeBrowser! sync`).
- Stabilize headless E2E startup by using explicit `lua` command invocations.

### Changed
- Updated command completion and help text to reflect inline command flow.
- Expanded integration coverage for command completion and shorthand command behavior.
- Release pipeline now uploads `themes.json` and `manifest.json` assets.
- Release pipeline validates uploaded assets before completing.

## [0.3.2] - 2026-02-27

### Added
- Curated Eldritch variant list in registry overrides.

[0.4.3]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.4.3
[0.4.2]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.4.2
[0.4.1]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.4.1
[0.4.0]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.4.0
[0.3.5]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.3.5
[0.3.4]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.3.4
[0.3.3]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.3.3
[0.3.2]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.3.2
