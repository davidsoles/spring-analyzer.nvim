# Architecture Plan — spring-analyzer.nvim

Neovim/LazyVim client for the SpringAnalyzer scanner. It runs the Java analyzer,
caches its output per project, and displays the result with
`folke/snacks.nvim`.

## 1. Goals

1. Run the scanner asynchronously.
2. Cache results per project.
3. Display endpoints in a Snacks picker.
4. Refresh or invalidate the cache manually.
5. Keep the cache reasonably fresh after saves.
6. Download the scanner JAR automatically when it is missing.

The plugin does not reimplement the parser in Lua. Java source analysis stays in
the `spring-analyzer` CLI.

## 2. Key decisions

| Topic | Decision | Reason |
|---|---|---|
| Analysis engine | External Java JAR | Reuses the tested JavaParser implementation. |
| Execution | `vim.system`, asynchronous | Never blocks the UI. |
| Frequency | Full scan with debounce on save | Correct with cross-file constants and annotations. |
| Per-file incremental | Deferred | The scanner indexes the whole repo; filtering output does not avoid parsing. |
| Cache | JSON in `stdpath("cache")` | Does not dirty the repository; survives restarts. |
| UI | `Snacks.picker.pick({ items = ... })` | Native LazyVim/Snacks integration. |
| Concurrency | One scan at a time, callback queue | Avoids races and partial writes. |
| Invalidation | `clear`, `clear all`, `refresh` | Explicit user control. |
| Scanner distribution | GitHub Release + SHA-256 | Simple to install, verifiable. |

## 3. Flow

```text
BufWritePost (*.java, pom.xml, build.gradle)
        │
        ▼
  debounce 750 ms
        │
        ▼
  spring_analyzer.scanner.scan(root)
        │
        ├── downloader.ensure(cfg)
        │     ├── scanner.jar
        │     ├── <plugin>/bin/spring-analyzer.jar
        │     ├── stdpath("data")/spring-analyzer/bin/<version>/...
        │     └── GitHub Release + SHA-256
        │
        ├── java -jar spring-analyzer.jar --format json --verbose <root>
        │
        ▼
  JSON envelope: { schemaVersion, scannerVersion, endpoints }
        │
        ▼
  cache.write(root, data)   (tmp + atomic rename)
        │
        ├── if requested: picker.show(root, endpoints)
        │
        ▼
  (an already-open picker is not updated live in the MVP)
```

## 4. When does the analysis run?

| Event | Action | UI |
|---|---|---|
| `:SpringAnalyzer` | Show fresh cache, or show stale cache and refresh in background, or scan then show. | Yes |
| `:SpringAnalyzer refresh` | Cancel current scan, clear cache, full scan, show. | Yes |
| `:SpringAnalyzer clear` | Delete current project cache. | No |
| `:SpringAnalyzer clear all` | Delete all SpringAnalyzer caches. | No |
| `:SpringAnalyzer status` | Show root, endpoint count, cache path, age, staleness. | No |
| `:SpringAnalyzer cancel` | Cancel the running scan. | No |
| `:SpringAnalyzer install` | Download/install the scanner JAR. | No |
| `:SpringAnalyzer doctor` | Show Java, JAR, cache, and root diagnostics. | No |
| `BufWritePost *.java` | Debounced silent full scan; update cache. | No |
| `BufWritePost pom.xml` / Gradle | Same as above. | No |
| `BufEnter` / `VimEnter` `*.java` | Read cache; refresh silently if missing or stale. | No |
| `VimLeavePre` | Cancel pending scans. | No |

### Why full scan instead of per-file scan?

The scanner indexes all Java files to resolve constants, composed annotations,
interfaces, and base classes. Running it only on the saved file would produce
false negatives. JVM startup and full parsing usually dominate the cost anyway.

Future incremental options:

1. `--changed-file` in the scanner: index everything, emit only the changed file,
   then replace that file's entries in the cache.
2. A persistent Java index between runs.
3. A file watcher (`uv.fs_event`) for changes made outside Neovim.
4. Per-module caches in monorepos.

## 5. Cache

Location:

```text
<stdpath("cache")>/spring-analyzer/<sha256(root)[:16]>.json
```

Schema:

```json
{
  "version": 1,
  "root": "/path/to/project",
  "generated_at": 1760000000,
  "schemaVersion": 1,
  "scannerVersion": "1.0.0",
  "scanner": {
    "jar": "/path/to/spring-analyzer.jar",
    "jar_mtime": 1759999999
  },
  "stderr": "",
  "endpoints": []
}
```

Writes use a temporary file plus `fs_rename`. A cache is stale when it is
missing, malformed, older than `cache.max_age`, or the scanner JAR changed.

## 6. Scanner download

Resolution order:

1. `scanner.jar` (explicit, no download).
2. `<plugin>/bin/spring-analyzer.jar` (local development).
3. `stdpath("data")/spring-analyzer/bin/<version>/spring-analyzer.jar`.
4. GitHub Release download with checksum.
5. Clear error message.

Download rules:

- URL template is configurable.
- Version is pinned; no “latest” by default.
- HTTPS only in the default URL.
- Download to `.part`.
- Fetch `<jar-url>.sha256` and verify with SHA-256.
- Atomic rename after verification.
- Keep the previous valid JAR if an update fails.
- Never download during `setup()`; download on first use or via an explicit
  command.

Cache location for binaries is `stdpath("data")`, not `stdpath("cache")`, because
downloads are installed tools rather than disposable cache entries.

## 7. Picker

Each item:

```lua
{
  text = "GET    /api/users    UserController#list    src/.../UserController.java:20",
  spring = endpoint,
  file = "/absolute/path/UserController.java",
  pos = { 20, 0 },
}
```

- `text` includes verb, path, handler, and file for fuzzy matching.
- `format` colors the verb, path, and handler.
- `preview = "file"` previews the source.
- `confirm` opens the file and moves the cursor to the annotation line.

Future: group by controller, filter by verb, copy `curl`, open in split, and an
optional Telescope adapter.

## 8. Commands and Lua API

Commands:

- `:SpringAnalyzer`
- `:SpringAnalyzer` (open picker)
- `:SpringAnalyzer refresh`
- `:SpringAnalyzer clear [all]`
- `:SpringAnalyzer status`
- `:SpringAnalyzer cancel`
- `:SpringAnalyzer install`
- `:SpringAnalyzer doctor`
- `:SpringAnalyzer help`

API:

```lua
local spring = require("spring_analyzer")

spring.setup(opts)
spring.show()
spring.refresh({ root = root, clear = true, show = true, notify = true })
spring.install()
spring.doctor()
spring.clear()
spring.clear_all()
spring.status()
spring.cancel()
```

## 9. Modules

```text
lua/spring_analyzer/
├── init.lua        # setup, public API, autocmds
├── config.lua      # defaults and option merging
├── util.lua        # root detection, paths, filetype
├── downloader.lua  # JAR resolution, download, checksum, Java version
├── scanner.lua     # vim.system, JSON, concurrency, cancellation
├── cache.lua       # atomic read/write, staleness, cleanup
└── picker.lua      # snacks.nvim integration
```

## 10. Error handling

- Missing JAR: clear notification with install instructions.
- Non-zero exit code: show scanner `stderr`.
- Invalid JSON: do not write cache.
- Scan failure on save: keep the previous cache.
- Rapid saves: 750 ms debounce.
- Scan in progress: queue callbacks and reuse the result.
- Cancellation: generation token ignores stale callbacks.
- Multiple Neovim instances: atomic writes; last writer wins.
- Security: `vim.system` gets an argument list, not a shell string.

## 11. Testing

Headless Neovim smoke tests:

```bash
nvim --headless --clean \
  --cmd "set rtp+=." \
  -c "lua require('spring_analyzer').setup({ auto = { on_save = false, on_open = false } })" \
  -c "lua assert(type(require('spring_analyzer.scanner').command) == 'function')" \
  -c "qa!"
```

Test cases to add:

- Cache write/read/delete and corruption handling.
- Scanner argument generation.
- JSON envelope parsing.
- Downloader with a local HTTP fixture and checksum mismatch.
- Picker item mapping (`file`, `pos`).
- Cancellation and queued callbacks.

## 12. Roadmap

### Phase 0 — MVP (implemented)

- Async scanner.
- Atomic per-project cache.
- Snacks picker.
- Refresh/clear/status/cancel/install/doctor commands.
- Save debounce.
- Stale refresh on open.
- JAR auto-download with checksum.

### Phase 1 — Polish

- Automated headless tests.
- `:help spring-analyzer`.
- CI formatting and linting.
- Release packaging.

### Phase 2 — Performance

- Measure full scans on real repositories.
- Add `--changed-file` and incremental cache updates if needed.
- Per-module caches and file watching.

### Phase 3 — UX

- Filter by verb/controller.
- Copy `curl`.
- Open in split.
- Optional Telescope adapter.
- Event publisher/subscriber graph.

## 13. Open decisions

1. Repository root (`.git`) vs module root (`pom.xml`) in monorepos.
   - MVP: `.git` first, then nearest build file.
2. Cache TTL: 300 seconds by default, configurable.
3. Bundled JAR vs download: both supported; explicit `scanner.jar` wins.
4. Auto-open picker on Java files: no; only prepare the cache.
5. True incremental updates: only if measurements justify them.
