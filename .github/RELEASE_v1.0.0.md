# spring-analyzer.nvim v1.0.0

Initial release of the SpringAnalyzer Neovim client.

## Features

- Asynchronous Spring Boot endpoint scanning.
- Per-project cache with atomic writes.
- Snacks picker with fuzzy matching by verb, path, handler, or file.
- Jump to the mapping annotation in the source file.
- Automatic scanner JAR download from GitHub Releases with SHA-256 verification.
- Refresh after saving Java files, with debounce.
- Background refresh when opening Java files if the cache is stale.
- Commands for install, refresh, clear, status, cancel, and diagnostics.

## Requirements

- Neovim 0.10+
- LazyVim with `folke/snacks.nvim`
- Java 21+
- `curl` for automatic scanner downloads

## Installation

```lua
{
  "davidsoles/spring-analyzer.nvim",
  ft = "java",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    scanner = {
      version = "1.0.0",
      auto_download = true,
    },
  },
  config = function(_, opts)
    require("spring_analyzer").setup(opts)
  end,
}
```

## Commands

- `:SpringAnalyzer`
- `:SpringAnalyzerRefresh`
- `:SpringAnalyzerClear[!]`
- `:SpringAnalyzerStatus`
- `:SpringAnalyzerCancel`
- `:SpringAnalyzerInstall`
- `:SpringAnalyzerDoctor`

## Scanner

This plugin uses
[`spring-analyzer`](https://github.com/davidsoles/spring-analyzer) v1.0.0.
The scanner JAR is downloaded on first use and verified with SHA-256.

## License

Apache-2.0.
