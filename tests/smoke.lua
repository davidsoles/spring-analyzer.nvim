local root = vim.fn.getcwd()
vim.opt.rtp:append(root)

local ok, spring = pcall(require, "spring_analyzer")
assert(ok, spring)

spring.setup({
  auto = { on_save = false, on_open = false },
  scanner = { jar = "/nonexistent/spring-analyzer.jar" },
})

assert(type(spring.show) == "function")
assert(type(spring.refresh) == "function")
assert(type(spring.show_events) == "function")
assert(type(spring.update) == "function")
assert(type(spring.check_updates) == "function")
assert(type(spring.install) == "function")
assert(type(spring.doctor) == "function")
assert(type(require("spring_analyzer.scanner").command) == "function")
assert(type(require("spring_analyzer.cache").read) == "function")
assert(type(require("spring_analyzer.downloader").ensure) == "function")

local updater = require("spring_analyzer.updater")
assert(updater.is_newer("1.2.0", "1.1.0"))
assert(updater.is_newer("v2.0.0", "1.9.9"))
assert(not updater.is_newer("1.1.0", "1.1.0"))
assert(not updater.is_newer("1.0.0", "1.1.0"))

vim.cmd("runtime plugin/spring-analyzer.lua")
assert(vim.fn.exists(":SpringAnalyzer") == 2)
assert(vim.fn.exists(":SpringEndpoints") == 0)

print("spring-analyzer.nvim smoke test: ok")
