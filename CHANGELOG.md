# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and this project follows SemVer.

## [0.3.3] - 2026-02-27

### Fixed
- Accept top-level browser control commands (`:ThemeBrowser enable|disable|toggle`) without opening the picker.
- Simplify registry command UX with inline actions (`:ThemeBrowser sync|clear`, `:ThemeBrowser! sync`).
- Stabilize headless E2E startup by using explicit `lua` command invocations.

### Changed
- Updated command completion and help text to reflect inline command flow.
- Expanded integration coverage for command completion and shorthand command behavior.
- Release pipeline now uploads versioned archive assets and `SHA256SUMS.txt`.
- Release pipeline validates uploaded assets before completing.

## [0.3.2] - 2026-02-27

### Added
- Curated Eldritch variant list in registry overrides.

[0.3.3]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.3.3
[0.3.2]: https://github.com/raulcorreia7/theme-browser.nvim/releases/tag/v0.3.2
