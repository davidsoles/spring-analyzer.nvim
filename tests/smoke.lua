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
assert(type(spring.install) == "function")
assert(type(spring.doctor) == "function")
assert(type(require("spring_analyzer.scanner").command) == "function")
assert(type(require("spring_analyzer.cache").read) == "function")
assert(type(require("spring_analyzer.downloader").ensure) == "function")

vim.cmd("runtime plugin/spring-analyzer.lua")
assert(vim.fn.exists(":SpringAnalyzer") == 2)
assert(vim.fn.exists(":SpringEndpoints") == 0)

print("spring-analyzer.nvim smoke test: ok")
