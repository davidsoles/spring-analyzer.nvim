local M = {}

local uv = vim.uv or vim.loop
local downloader = require("spring_analyzer.downloader")

local SCHEMA_VERSION = 1

local state = {
  scanning = false,
  job = nil,
  root = nil,
  queue = {},
  generation = 0,
}

---@param root string
---@param cfg SpringAnalyzerConfig
---@param jar string
---@return string[]
function M.command(root, cfg, jar)
  local cmd = {
    cfg.scanner.java or "java",
    "-jar",
    jar,
    "--format",
    "json",
    "--verbose",
  }

  if cfg.scanner.include_tests then
    table.insert(cmd, "--include-tests")
  end
  if cfg.scanner.include_mvc then
    table.insert(cmd, "--include-mvc")
  end

  for _, argument in ipairs(cfg.scanner.extra_args or {}) do
    table.insert(cmd, argument)
  end

  table.insert(cmd, root)
  return cmd
end

---@return boolean
function M.is_scanning()
  return state.scanning
end

---Run the scanner asynchronously.
---@param root string
---@param cfg SpringAnalyzerConfig
---@param callback fun(err: string?, data: table?)
function M.scan(root, cfg, callback)
  callback = callback or function() end

  if state.scanning then
    if state.root == root then
      table.insert(state.queue, callback)
    else
      callback("Another scan is already running for " .. tostring(state.root))
    end
    return
  end

  state.generation = state.generation + 1
  local generation = state.generation

  state.scanning = true
  state.root = root
  state.queue = {}

  local function finish(failure, endpoints, stderr, jar, scanner_version)
    if generation ~= state.generation then
      return
    end

    state.scanning = false
    state.job = nil
    state.root = nil

    local queue = state.queue
    state.queue = {}

    local data = nil
    if not failure then
      local jar_stat = jar and uv.fs_stat(jar) or nil
      data = {
        schemaVersion = SCHEMA_VERSION,
        scannerVersion = scanner_version,
        endpoints = endpoints,
        stderr = stderr or "",
        scanner = {
          jar = jar,
          jar_mtime = jar_stat and jar_stat.mtime and jar_stat.mtime.sec or nil,
        },
      }
    end

    callback(failure, data)
    for _, queued in ipairs(queue) do
      queued(failure, data)
    end
  end

  downloader.ensure(cfg, function(download_err, jar)
    if generation ~= state.generation then
      return
    end
    if download_err then
      finish(download_err)
      return
    end

    local cmd = M.command(root, cfg, jar)

    local function on_exit(result)
      vim.schedule(function()
        local code = tonumber(result.code) or -1
        if code ~= 0 then
          finish(("scanner exited with code %d: %s"):format(
            code,
            (result.stderr or ""):sub(1, 2000)
          ))
          return
        end

        local ok, decoded = pcall(vim.json.decode, result.stdout or "")
        if not ok or type(decoded) ~= "table" then
          finish("scanner returned invalid JSON: " .. tostring(result.stdout):sub(1, 500))
          return
        end

        local schema = decoded.schemaVersion
        if schema and tonumber(schema) and tonumber(schema) > SCHEMA_VERSION then
          finish(("unsupported scanner JSON schema version %s (plugin supports %d)"):format(
            tostring(schema),
            SCHEMA_VERSION
          ))
          return
        end

        local endpoints = decoded.endpoints
        if type(endpoints) ~= "table" then
          -- Backward compatibility with the pre-envelope array output.
          if #decoded > 0 or next(decoded) == nil then
            endpoints = decoded
          else
            finish("scanner JSON does not contain an 'endpoints' array")
            return
          end
        end

        finish(nil, endpoints, result.stderr, jar, decoded.scannerVersion)
      end)
    end

    local ok, job = pcall(vim.system, cmd, { cwd = root, text = true }, on_exit)
    if not ok then
      finish("could not start the scanner: " .. tostring(job))
      return
    end

    state.job = job
  end)
end

---Cancel the current scan, if any.
---@param silent? boolean do not invoke queued callbacks
function M.cancel(silent)
  state.generation = state.generation + 1
  local queue = state.queue
  state.queue = {}

  if state.job then
    pcall(state.job.kill, state.job, "sigterm")
  end

  state.scanning = false
  state.job = nil
  state.root = nil

  if not silent then
    for _, callback in ipairs(queue) do
      callback("scan cancelled")
    end
  end
end

return M
