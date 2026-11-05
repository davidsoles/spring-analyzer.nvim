# Contributing

Thanks for your interest in spring-analyzer.nvim.

## Development setup

Requirements:

- Neovim 0.10+
- LazyVim with `folke/snacks.nvim`
- Java 21+ and a `spring-analyzer` JAR for end-to-end testing

Run the smoke test:

```bash
nvim --headless --clean \
  --cmd "set rtp+=." \
  -c "luafile tests/smoke.lua" \
  -c "qa!"
```

For manual testing, use a local JAR:

```lua
require("spring_analyzer").setup({
  scanner = {
    jar = "/path/to/spring-analyzer-1.0.0.jar",
  },
  auto = {
    on_save = false,
    on_open = false,
  },
})
```

## Pull requests

- Keep changes focused and add tests when possible.
- Update `README.md` and `CHANGELOG.md` for user-facing changes.
- Use English for comments, notifications, tests, and documentation.
- Do not commit downloaded or built JARs.
- Keep Lua compatible with Neovim's LuaJIT runtime.

## Reporting bugs

Open an issue with:

- Neovim version (`nvim --version`)
- Java version (`java -version`)
- Plugin and scanner versions
- `:SpringAnalyzer doctor` output
- Command used and actual/expected behavior

For security issues, follow [SECURITY.md](SECURITY.md).
