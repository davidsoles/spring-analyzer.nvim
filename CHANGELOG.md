# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Recommended keymaps moved from `<leader>s` to LazyVim's `<leader>c`
  (`code`) group: `<leader>ce`, `<leader>cE`, `<leader>cH`.

### Planned

- Event publisher/subscriber picker
- Relationship graph
- Per-file incremental cache updates

## [1.1.0] - 2026-11-04

### Changed

- Consolidated all user commands into a single `:SpringAnalyzer` command with
  subcommands: `refresh`, `clear [all]`, `status`, `cancel`, `install`,
  `doctor`, and `help`.
- Removed the many `:SpringAnalyzer*` and `:SpringEndpoints*` commands.

## [1.0.0] - 2026-11-04

### Added

- Initial SpringAnalyzer Neovim plugin.
- Asynchronous scanner execution.
- Per-project cache with atomic writes.
- Snacks picker with endpoint filters and source preview.
- Save debounce and stale-cache refresh on open.
- Automatic scanner JAR download from GitHub Releases with SHA-256 verification.
- Commands for install, refresh, clear, status, cancel, and diagnostics.
