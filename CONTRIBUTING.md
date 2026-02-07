# Contributing

Thanks for contributing to `theme-browser.nvim`.

## Development

1. Install dependencies (`nvim`, `python3`, optional `plenary.nvim`).
2. Run checks:

```bash
make verify
```

## Scope and Style

- Keep changes small and focused.
- Add tests for every bug fix.
- Prefer simple and composable Lua modules.
- Keep command and README behavior aligned.

## Testing

- Use `make verify` before sharing changes.
- Add unit tests for module behavior and integration tests for workflows.

## Reporting issues

Please include:

- Neovim version
- Lazy/LazyVim setup notes
- Steps to reproduce
- Expected vs actual behavior
