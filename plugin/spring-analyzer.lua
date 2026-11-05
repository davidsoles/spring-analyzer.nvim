if vim.g.loaded_spring_analyzer_nvim == 1 then
  return
end
vim.g.loaded_spring_analyzer_nvim = 1

local function spring()
  return require("spring_analyzer")
end

vim.api.nvim_create_user_command("SpringAnalyzer", function()
  spring().show()
end, {
  desc = "spring-analyzer: list REST endpoints",
})

vim.api.nvim_create_user_command("SpringEndpoints", function()
  spring().show()
end, {
  desc = "spring-analyzer: list REST endpoints (alias)",
})

vim.api.nvim_create_user_command("SpringAnalyzerRefresh", function()
  spring().refresh({ clear = true, show = true, notify = true })
end, {
  desc = "spring-analyzer: clear cache and rescan",
})

vim.api.nvim_create_user_command("SpringEndpointsRefresh", function()
  spring().refresh({ clear = true, show = true, notify = true })
end, {
  desc = "spring-analyzer: clear cache and rescan (alias)",
})

vim.api.nvim_create_user_command("SpringAnalyzerClear", function(args)
  if args.bang then
    spring().clear_all()
  else
    spring().clear()
  end
end, {
  bang = true,
  desc = "spring-analyzer: clear cache (bang for all)",
})

vim.api.nvim_create_user_command("SpringEndpointsClear", function(args)
  if args.bang then
    spring().clear_all()
  else
    spring().clear()
  end
end, {
  bang = true,
  desc = "spring-analyzer: clear cache (alias)",
})

vim.api.nvim_create_user_command("SpringAnalyzerStatus", function()
  spring().status()
end, {
  desc = "spring-analyzer: show cache status",
})

vim.api.nvim_create_user_command("SpringEndpointsStatus", function()
  spring().status()
end, {
  desc = "spring-analyzer: show cache status (alias)",
})

vim.api.nvim_create_user_command("SpringAnalyzerCancel", function()
  spring().cancel()
end, {
  desc = "spring-analyzer: cancel the current scan",
})

vim.api.nvim_create_user_command("SpringEndpointsCancel", function()
  spring().cancel()
end, {
  desc = "spring-analyzer: cancel the current scan (alias)",
})

vim.api.nvim_create_user_command("SpringAnalyzerInstall", function()
  spring().install()
end, {
  desc = "spring-analyzer: download and install the scanner JAR",
})

vim.api.nvim_create_user_command("SpringAnalyzerDoctor", function()
  spring().doctor()
end, {
  desc = "spring-analyzer: show scanner and cache diagnostics",
})
