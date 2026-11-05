# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Recommended keymaps: `<leader>ce` endpoints, `<leader>cE` events,
  `<leader>c<C-r>` refresh, `<leader>cH` diagnostics.

### Planned

- Scheduled task extraction
- Per-file incremental cache updates

## [1.3.0] - 2026-11-04

### Added

- Scanner update checks against GitHub Releases, cached for 24 hours by default.
- `:SpringAnalyzer update` downloads the latest scanner release, verifies its
  checksum, and rescans.
- `scanner.update_check = "notify" | "auto" | false`.
- `scanner.update_check_ttl` configuration.

### Changed

- Recommended keymaps moved from `<leader>s` to LazyVim's `<leader>c`
  (`code`) group: `<leader>ce`, `<leader>cE`, `<leader>cH`.

### Notes

- `:Lazy update` only updates this Neovim plugin; it does not update the
  scanner JAR.
- `:SpringAnalyzer update` changes the scanner version for the current session.
  Set `scanner.version` in the config to persist it across restarts.

## [1.2.0] - 2026-11-04

### Added

- Spring event graph: events, publishers, and subscribers.
- `:SpringAnalyzer events` shows a publisher -> subscriber tree.
- Support for scanner JSON schema version 2.
- Event counts in status output.

### Changed

- Scanner default version bumped to 1.1.0.
- Endpoint picker now uses per-item previews so event-tree nodes can show text
  previews when they have no source file.

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
