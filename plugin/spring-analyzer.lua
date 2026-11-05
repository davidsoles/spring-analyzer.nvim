if vim.g.loaded_spring_analyzer_nvim == 1 then
  return
end
vim.g.loaded_spring_analyzer_nvim = 1

local function spring()
  return require("spring_analyzer")
end

local function print_help()
  vim.notify(
    table.concat({
      "SpringAnalyzer",
      "",
      ":SpringAnalyzer                 Open the endpoint picker",
      ":SpringAnalyzer events          Show publishers and subscribers",
      ":SpringAnalyzer refresh         Clear cache and rescan",
      ":SpringAnalyzer clear           Clear the current project cache",
      ":SpringAnalyzer clear all       Clear all caches",
      ":SpringAnalyzer status          Show cache status",
      ":SpringAnalyzer cancel          Cancel the current scan",
      ":SpringAnalyzer install         Download/install the scanner JAR",
      ":SpringAnalyzer doctor          Show diagnostics",
      ":SpringAnalyzer help            Show this help",
    }, "\n"),
    vim.log.levels.INFO
  )
end

local subcommands = {
  events = {
    desc = "Show publishers and subscribers",
    run = function()
      spring().show_events()
    end,
  },
  refresh = {
    desc = "Clear cache and rescan",
    run = function()
      spring().refresh({ clear = true, show = true, notify = true })
    end,
  },
  clear = {
    desc = "Clear cache",
    run = function(args)
      if args[2] == "all" then
        spring().clear_all()
      else
        spring().clear()
      end
    end,
  },
  status = {
    desc = "Show cache status",
    run = function()
      spring().status()
    end,
  },
  cancel = {
    desc = "Cancel the current scan",
    run = function()
      spring().cancel()
    end,
  },
  install = {
    desc = "Download and install the scanner JAR",
    run = function()
      spring().install()
    end,
  },
  doctor = {
    desc = "Show scanner and cache diagnostics",
    run = function()
      spring().doctor()
    end,
  },
  help = {
    desc = "Show help",
    run = print_help,
  },
}

local function complete(arglead, cmdline)
  local parts = vim.split(cmdline, "%s+", { trimempty = true })
  if parts[2] == "clear" then
    if vim.startswith("all", arglead) then
      return { "all" }
    end
    return {}
  end

  local matches = {}
  for name in pairs(subcommands) do
    if vim.startswith(name, arglead) then
      table.insert(matches, name)
    end
  end
  table.sort(matches)
  return matches
end

vim.api.nvim_create_user_command("SpringAnalyzer", function(opts)
  local args = opts.fargs
  local subcommand = args[1]

  if not subcommand then
    spring().show()
    return
  end

  local entry = subcommands[subcommand]
  if not entry then
    vim.notify("spring-analyzer: unknown subcommand: " .. subcommand, vim.log.levels.ERROR)
    print_help()
    return
  end

  entry.run(args)
end, {
  nargs = "*",
  desc = "SpringAnalyzer: endpoints and diagnostics",
  complete = complete,
})
