local M = {}

local config = require("spring_analyzer.config")
local cache = require("spring_analyzer.cache")
local scanner = require("spring_analyzer.scanner")
local downloader = require("spring_analyzer.downloader")
local picker = require("spring_analyzer.picker")
local util = require("spring_analyzer.util")

local options
local pending_refresh = {}

local function ensure_setup()
  if not options then
    M.setup()
  end
  return options
end

---@param message string
---@param level? integer
local function notify(message, level)
  if options and options.ui and options.ui.notify == false then
    return
  end
  vim.notify("spring-analyzer: " .. message, level or vim.log.levels.INFO)
end

---@param opts? table
---@return table
function M.setup(opts)
  options = config.setup(opts)
  M.options = options

  local group = vim.api.nvim_create_augroup("SpringAnalyzer", { clear = true })

  if options.auto.on_save then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      pattern = {
        "*.java",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
        "settings.gradle",
        "settings.gradle.kts",
      },
      callback = function(args)
        local root = util.root(args.buf, { fallback = false })
        if root then
          M.schedule_refresh(root)
        end
      end,
      desc = "spring-analyzer: refresh cache after saving",
    })
  end

  if options.auto.on_open then
    vim.api.nvim_create_autocmd({ "BufEnter", "VimEnter" }, {
      group = group,
      pattern = "*.java",
      callback = function(args)
        M.ensure_cache(args.buf)
      end,
      desc = "spring-analyzer: prepare cache when opening Java files",
    })
  end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      pending_refresh = {}
      scanner.cancel(true)
    end,
    desc = "spring-analyzer: cancel pending scans",
  })

  return M
end

---Show the endpoint picker. Scans first when there is no cache.
function M.show()
  ensure_setup()

  local root = util.root(0, { fallback = true })
  if not root then
    notify("could not find a Java/Spring project", vim.log.levels.WARN)
    return
  end

  local data = cache.read(root, options)
  if data then
    picker.show(root, data.endpoints, options)
    if cache.is_stale(data, options) then
      notify("cache is stale; refreshing in the background...", vim.log.levels.INFO)
      M.refresh({ root = root, clear = false, show = false, notify = false })
    end
    return
  end

  notify("scanning " .. root .. "...", vim.log.levels.INFO)
  M.refresh({ root = root, clear = false, show = true, notify = true })
end

---Show the event publisher/subscriber tree. Scans first when there is no cache.
function M.show_events()
  ensure_setup()

  local root = util.root(0, { fallback = true })
  if not root then
    notify("could not find a Java/Spring project", vim.log.levels.WARN)
    return
  end

  local data = cache.read(root, options)
  if data then
    picker.show_events(root, data.events or {}, options)
    if cache.is_stale(data, options) or (data.schemaVersion or 1) < 2 then
      notify("cache is stale or outdated; refreshing in the background...", vim.log.levels.INFO)
      M.refresh({ root = root, clear = false, show_events = false, notify = false })
    end
    return
  end

  notify("scanning " .. root .. "...", vim.log.levels.INFO)
  M.refresh({ root = root, clear = false, show_events = true, notify = true })
end

---Run the scanner and update the cache.
---@param opts? { root?: string, clear?: boolean, show?: boolean, notify?: boolean }
function M.refresh(opts)
  opts = opts or {}
  ensure_setup()

  local root = opts.root or util.root(0, { fallback = true })
  if not root then
    notify("could not find a Java/Spring project", vim.log.levels.WARN)
    return
  end

  if opts.clear then
    scanner.cancel()
    cache.delete(root, options)
  end

  scanner.scan(root, options, function(err, data)
    if err then
      if opts.notify then
        notify(err, vim.log.levels.ERROR)
      end
      return
    end

    if not data then
      if opts.notify then
        notify("scanner returned no data", vim.log.levels.ERROR)
      end
      return
    end

    data.version = cache.VERSION
    data.root = root
    data.generated_at = os.time()

    local ok, write_err = cache.write(root, data, options)
    if not ok then
      if opts.notify then
        notify("could not write cache: " .. tostring(write_err), vim.log.levels.ERROR)
      end
      return
    end

    if opts.show then
      picker.show(root, data.endpoints, options)
    elseif opts.show_events then
      picker.show_events(root, data.events or {}, options)
    end

    if opts.notify then
      notify(("%d endpoints updated"):format(#data.endpoints), vim.log.levels.INFO)
    end
  end)
end

---Download and install the configured scanner JAR.
function M.install()
  ensure_setup()

  downloader.install(options, function(err, path)
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    notify("scanner installed at " .. path, vim.log.levels.INFO)
  end, true)
end

---Show diagnostics for the scanner, Java runtime, and cache.
function M.doctor()
  ensure_setup()

  local root = util.root(0, { fallback = true })
  local explicit = downloader.explicit_jar(options)
  local jar = explicit or downloader.cached_path(options)
  local found = vim.fn.filereadable(jar) == 1

  local lines = {
    "root: " .. (root or "<none>"),
    "java: " .. (options.scanner.java or "java"),
    "jar: " .. jar .. (found and " (found)" or " (missing)"),
    "scanner version: " .. tostring(options.scanner.version),
    "auto download: " .. tostring(options.scanner.auto_download ~= false),
  }

  if root then
    table.insert(lines, "cache: " .. cache.path(root, options))
  end

  local data = root and cache.read(root, options) or nil
  if data then
    table.insert(lines, ("cache endpoints: %d"):format(#data.endpoints))
    table.insert(lines, "cache status: " .. (cache.is_stale(data, options) and "stale" or "fresh"))
  else
    table.insert(lines, "cache: <empty>")
  end

  downloader.java_version(options, function(major)
    table.insert(lines, "java major: " .. tostring(major or "unknown"))
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end)
end

---Prepare the cache when opening a Java file, without blocking the UI.
---@param buf integer
function M.ensure_cache(buf)
  ensure_setup()

  if not options.auto.on_open then
    return
  end

  local root = util.root(buf, { fallback = false })
  if not root then
    return
  end

  local data = cache.read(root, options)
  if data and not cache.is_stale(data, options) then
    return
  end

  if scanner.is_scanning() then
    return
  end

  M.refresh({ root = root, clear = false, show = false, notify = false })
end

---Group rapid saves so the scanner does not run on every write.
---@param root string
function M.schedule_refresh(root)
  ensure_setup()

  if not root or pending_refresh[root] then
    return
  end

  pending_refresh[root] = true
  vim.defer_fn(function()
    pending_refresh[root] = nil
    M.refresh({ root = root, clear = false, show = false, notify = false })
  end, options.auto.debounce or 750)
end

---Delete the cache for the current project.
function M.clear()
  ensure_setup()

  local root = util.root(0, { fallback = true })
  if not root then
    notify("could not find a Java/Spring project", vim.log.levels.WARN)
    return
  end

  scanner.cancel()

  local ok, err = cache.delete(root, options)
  if not ok then
    notify("could not delete cache: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  notify("cache deleted for " .. root, vim.log.levels.INFO)
end

---Delete every SpringAnalyzer cache entry.
function M.clear_all()
  ensure_setup()
  scanner.cancel()

  local ok, err = cache.clear_all(options)
  if not ok then
    notify("could not delete caches: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  notify("all caches deleted", vim.log.levels.INFO)
end

---Cancel the current scan.
function M.cancel()
  ensure_setup()

  if not scanner.is_scanning() then
    notify("no scan is currently running", vim.log.levels.INFO)
    return
  end

  scanner.cancel()
  notify("scan cancelled", vim.log.levels.INFO)
end

---Show the current cache status.
function M.status()
  ensure_setup()

  local root = util.root(0, { fallback = true })
  if not root then
    notify("could not find a Java/Spring project", vim.log.levels.WARN)
    return
  end

  local data = cache.read(root, options)
  if not data then
    notify("no cache for " .. root, vim.log.levels.INFO)
    return
  end

  local generated = data.generated_at or 0
  local age = os.time() - generated
  local lines = {
    "root: " .. root,
    ("endpoints: %d"):format(#data.endpoints),
    ("events: %d"):format(#(data.events or {})),
    ("cache: %s"):format(cache.path(root, options)),
    ("generated: %s (%ds ago)"):format(os.date("%Y-%m-%d %H:%M:%S", generated), age),
    ("status: %s"):format(cache.is_stale(data, options) and "stale" or "fresh"),
  }

  local jar = data.scanner and data.scanner.jar
  if jar then
    table.insert(lines, "scanner: " .. jar)
  end

  if data.stderr and data.stderr ~= "" then
    table.insert(lines, "stderr: " .. data.stderr:sub(1, 1000))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
