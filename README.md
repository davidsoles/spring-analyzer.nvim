# spring-analyzer.nvim

Neovim/LazyVim plugin that lists REST endpoints from Spring Boot projects and
jumps to the exact source line where each endpoint is declared.

It is the Neovim client for
[`spring-analyzer`](https://github.com/davidsoles/spring-analyzer), a static
analysis CLI for Spring Boot. The scanner does not need to compile or run the
application.

> This is an independent open-source project. It is not affiliated with,
> endorsed by, or sponsored by Spring or Broadcom.

## Features

- Asynchronous scanning with `vim.system`; Neovim stays responsive.
- Per-project cache under `stdpath("cache")`.
- Snacks picker with fuzzy matching by HTTP verb, path, handler, or file.
- Opens the source file and places the cursor on the mapping annotation.
- Event graph picker: publishers and their subscribers in a tree.
- Automatic refresh after saving Java files, with debounce.
- Background refresh when opening a Java file if the cache is stale.
- Automatic scanner JAR download from GitHub Releases, with SHA-256
  verification.
- Manual install, cache invalidation, cancellation, and diagnostics commands.
- No Lua dependencies beyond `folke/snacks.nvim`.

## Requirements

- Neovim 0.10+ (tested with 0.12).
- LazyVim with `folke/snacks.nvim`.
- Java 21+ to run the scanner.
- `curl` for automatic JAR downloads (optional if you configure a local JAR).
- The `spring-analyzer` scanner JAR:
  - downloaded automatically, or
  - configured with `scanner.jar`, or
  - placed at `<plugin>/bin/spring-analyzer.jar`.

## Installation

### With lazy.nvim / LazyVim

```lua
return {
  {
    "davidsoles/spring-analyzer.nvim",
    ft = "java",
    cmd = { "SpringAnalyzer" },
    keys = {
      { "<leader>ce", "<cmd>SpringAnalyzer<cr>", desc = "SpringAnalyzer: endpoints" },
      { "<leader>cE", "<cmd>SpringAnalyzer events<cr>", desc = "SpringAnalyzer: events" },
      { "<leader>c<C-r>", "<cmd>SpringAnalyzer refresh<cr>", desc = "SpringAnalyzer: refresh" },
      { "<leader>ci", "<cmd>SpringAnalyzer doctor<cr>", desc = "SpringAnalyzer: diagnostics" },
    },
    -- ce = endpoints, cE = events, c<C-r> = refresh, ci = diagnostics.
    -- These avoid LazyVim's ca, cc, cd, cf, cm, co, cr, cs, and cS.
    dependencies = { "folke/snacks.nvim" },
    opts = {
      scanner = {
        version = "1.1.0",
        auto_download = true,
      },
      auto = {
        on_save = true,
        on_open = true,
        debounce = 750,
      },
    },
    config = function(_, opts)
      require("spring_analyzer").setup(opts)
    end,
  },
}
```

### Local development

Use a directory spec while developing both projects:

```lua
{
  dir = "/home/dsoles/Neovim/spring-analyzer.nvim",
  name = "spring-analyzer.nvim",
  ft = "java",
  config = function(_, opts)
    require("spring_analyzer").setup(opts)
  end,
  opts = {
    scanner = {
      -- Local JAR wins over auto-download.
      jar = "/home/dsoles/Java/spring-analyzer/target/spring-analyzer-1.1.0.jar",
    },
    auto = { on_save = false, on_open = false },
  },
}
```

A complete example is available at [`examples/lazyvim.lua`](examples/lazyvim.lua).

## Scanner installation

The plugin resolves the scanner JAR in this order:

1. `scanner.jar`, if configured and present.
2. `<plugin>/bin/spring-analyzer.jar`, if present.
3. A downloaded JAR under:

   ```text
   <stdpath("data")>/spring-analyzer/bin/<version>/spring-analyzer.jar
   ```

4. If `auto_download = true`, download it from GitHub Releases and verify its
   SHA-256 checksum.
5. Otherwise show an error with instructions.

Download URL template:

```text
https://github.com/davidsoles/spring-analyzer/releases/download/v%s/spring-analyzer-%s.jar
```

The checksum is fetched from the same URL with `.sha256` appended. The JAR is
downloaded to a temporary file, verified, and moved into place atomically.

Manual installation:

```vim
:SpringAnalyzer install
```

Diagnostics:

```vim
:SpringAnalyzer doctor
```

## Updating

There are three separate update paths:

1. **Plugin code**: `:Lazy update` updates `spring-analyzer.nvim` from GitHub.
2. **Scanner JAR**: `:SpringAnalyzer update` checks GitHub Releases, downloads
   the latest scanner, verifies its checksum, and rescans.
3. **Project cache**: `:SpringAnalyzer refresh` only rescans with the current
   scanner.

`update_check` controls the automatic release check:

```lua
scanner = {
  update_check = "notify", -- false | "notify" | "auto"
  update_check_ttl = 86400, -- seconds
}
```

- `"notify"` shows a warning when a newer scanner exists.
- `"auto"` downloads the newer scanner automatically.
- `false` disables automatic checks. `:SpringAnalyzer update` still works.

`:SpringAnalyzer update` changes the scanner version for the current Neovim
session. To persist it, set `scanner.version` in your config to the new version.

## Commands

| Command | Description |
|---|---|
| `:SpringAnalyzer` | Open the endpoint picker. |
| `:SpringAnalyzer events` | Show the publisher -> subscriber tree. |
| `:SpringAnalyzer refresh` | Clear the cache and rescan. |
| `:SpringAnalyzer clear` | Clear the current project cache. |
| `:SpringAnalyzer clear all` | Clear all SpringAnalyzer caches. |
| `:SpringAnalyzer status` | Show cache path, age, and endpoint count. |
| `:SpringAnalyzer cancel` | Cancel the current scan. |
| `:SpringAnalyzer install` | Download/install the configured scanner JAR. |
| `:SpringAnalyzer update` | Download the latest scanner release and rescan. |
| `:SpringAnalyzer doctor` | Show Java, JAR, cache, and root diagnostics. |
| `:SpringAnalyzer help` | Show command help. |

There is only one command; use its subcommands.

## Configuration

```lua
require("spring_analyzer").setup({
  scanner = {
    java = nil,        -- defaults to exepath("java") or "java"
    jar = nil,         -- explicit JAR; wins over auto-download
    version = "1.1.0", -- scanner release to download
    auto_download = true,
    update_check = "notify", -- false | "notify" | "auto"
    update_check_ttl = 86400,
    download_url = "https://github.com/davidsoles/spring-analyzer/releases/download/v%s/spring-analyzer-%s.jar",
    checksum_url = nil, -- defaults to <jar-url>.sha256
    checksum = nil,     -- optional expected SHA-256
    include_tests = false,
    include_mvc = false,
    extra_args = {},
  },
  cache = {
    dir = nil,      -- defaults to stdpath("cache")/spring-analyzer
    max_age = 300,  -- seconds; 0 means it never expires
  },
  auto = {
    on_save = true,
    on_open = true,
    debounce = 750,
  },
  ui = {
    notify = true,
    picker = {
      title = "SpringAnalyzer Endpoints",
    },
  },
})
```

## Cache

Location:

```text
<stdpath("cache")>/spring-analyzer/<sha256(root)[:16]>.json
```

Each entry stores:

- cache version
- project root
- scanner version and JAR path/mtime
- scanner `stderr`
- endpoints array
- events array (publishers and subscribers)

Writes are atomic (`tmp` + `fs_rename`). A corrupted or incompatible cache is
ignored and rebuilt.

A cache is considered stale when:

- it does not exist,
- `max_age` has elapsed,
- the scanner JAR changed,
- or the JSON cannot be decoded.

## How it works

1. Detect the project root (`.git`, `pom.xml`, Gradle files, etc.).
2. Run in the background:

   ```bash
   java -jar spring-analyzer.jar --format json --verbose <root>
   ```

3. Store the endpoint array in the per-project cache.
4. Display it with `Snacks.picker.pick`.
5. After saving Java files, debounce and rescan.
6. When opening Java files, refresh in the background if the cache is stale.

The JSON contract is versioned:

```json
{
  "schemaVersion": 2,
  "scannerVersion": "1.1.0",
  "endpoints": [],
  "events": []
}
```

The plugin accepts schema versions up to 2. Scanner 1.0.0 (schema 1) still works
for endpoints; event support requires scanner 1.1.0 or newer.

## Events

`:SpringAnalyzer events` shows the event graph in a Snacks tree:

```text
OrderCreatedEvent
├─ OrderService#create
│  ├─ OrderListener#onCreated
│  ├─ OrderListener#afterCommit
│  ├─ OrderListener#onCustom
│  └─ OrderListener#onMultiple
├─ OrderService#ship
│  └─ ...
└─ OrderService#createFromFactory
   └─ ...
```

Events without a publisher or without subscribers are shown explicitly, so
orphan listeners and unpublished events are easy to spot.

Spring Boot lifecycle events are labeled instead of showing a misleading
"no publisher found":

```text
ApplicationReadyEvent
└─ BOOT Spring Boot lifecycle
   └─ SUB WeatherScheduler#initWeatherUpdate
```

The underlying JSON field is `publisherOrigin`:

- `application`: publisher found in the repository.
- `framework`: Spring Boot/Spring lifecycle event.
- `external`: publisher outside the repository.
- `none`: event declared in the repository but never published.

## Picker

The endpoint picker shows one row per endpoint. The event picker shows a tree of
event -> publisher -> subscriber.

Endpoint items contain:

- HTTP verb
- full path
- `Controller#method`
- source file and line

Confirming an item opens the file and places the cursor on the mapping
annotation. The preview shows the source file.

## Limitations

- Static analysis only; it does not execute Spring.
- Constants from external dependencies and dynamic expressions are not resolved.
- Conditional beans and runtime context paths are not evaluated.
- Publisher detection for `publishEvent`/`multicastEvent` can be name-only when
  the receiver type cannot be resolved. Such publishers are marked with
  `confidence = "name-only"`.
- Synchronous and asynchronous listeners are listed the same; the plugin does
  not distinguish `@Async` or transactional phases.
- Java only; Kotlin and Groovy are not supported.
- Full rescan per save; per-file incremental updates are planned.

## Troubleshooting

### `scanner JAR not found`

Run:

```vim
:SpringAnalyzer install
```

Or set `scanner.jar` to a local build:

```lua
scanner = {
  jar = "/home/dsoles/Java/spring-analyzer/target/spring-analyzer-1.1.0.jar",
}
```

### `curl is required`

Install `curl`, or configure a local JAR and disable auto-download.

### Wrong Java version

Run:

```vim
:SpringAnalyzer doctor
```

Configure `scanner.java` with a Java 21+ executable if needed.

### Nothing appears

- Check that the current file is inside a Git or Maven/Gradle project.
- Run `:SpringAnalyzer status`.
- Run `:SpringAnalyzer doctor`.
- Run `:SpringAnalyzer refresh`.

## Roadmap

- Stable endpoint picker and scanner download.
- Event publisher/subscriber picker. **Done in 1.2.0.**
- Scanner update checks and `:SpringAnalyzer update`. **Done in 1.3.0.**
- Scheduled task extraction.
- Optional Telescope adapter.

## License

Apache License 2.0. See [LICENSE](LICENSE).

See [`PLAN.md`](PLAN.md) for the architecture and design decisions.
