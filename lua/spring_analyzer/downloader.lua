local M = {}

local uv = vim.uv or vim.loop

local state = {
  downloading = false,
  queue = {},
}

---@return string
local function plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
end

---@return string
function M.bundled_path()
  return vim.fs.normalize(vim.fs.joinpath(plugin_root(), "bin", "spring-analyzer.jar"))
end

local function notify(cfg, message, level)
  if cfg and cfg.ui and cfg.ui.notify == false then
    return
  end
  vim.notify("spring-analyzer: " .. message, level or vim.log.levels.INFO)
end

local function schedule(callback, err, path)
  vim.schedule(function()
    callback(err, path)
  end)
end

---@param cfg SpringAnalyzerConfig
---@return string
function M.cached_path(cfg)
  local version = tostring(cfg.scanner.version or "1.0.0")
  return vim.fs.normalize(
    vim.fs.joinpath(vim.fn.stdpath("data"), "spring-analyzer", "bin", version, "spring-analyzer.jar")
  )
end

---@param cfg SpringAnalyzerConfig
---@return string?
function M.jar_url(cfg)
  local template = cfg.scanner.download_url
  if not template or template == "" then
    return nil
  end
  local ok, url = pcall(string.format, template, cfg.scanner.version, cfg.scanner.version)
  if not ok then
    return nil
  end
  return url
end

---@param cfg SpringAnalyzerConfig
---@param jar_url string
---@return string
function M.checksum_url(cfg, jar_url)
  return cfg.scanner.checksum_url or (jar_url .. ".sha256")
end

---@param cfg SpringAnalyzerConfig
---@return string?, string?
function M.explicit_jar(cfg)
  local configured = cfg.scanner.jar
  if not configured or configured == "" then
    return nil
  end
  if vim.fn.filereadable(configured) == 1 then
    return configured
  end
  return nil, "Configured scanner.jar does not exist: " .. configured
end

---@param path string
---@param expected string
---@return boolean, string?
function M.verify(path, expected)
  local file = io.open(path, "rb")
  if not file then
    return false, "cannot read " .. path
  end
  local content = file:read("*a")
  file:close()

  local actual = vim.fn.sha256(content)
  return actual:lower() == expected:lower(), actual
end

---@param text string
---@return string?
local function parse_checksum(text)
  for token in text:gmatch("%x+") do
    if #token == 64 then
      return token:lower()
    end
  end
  return nil
end

---@param args string[]
---@param callback fun(err: string?, result: table?)
local function curl(args, callback)
  if vim.fn.executable("curl") ~= 1 then
    callback("curl is required to download the scanner JAR")
    return
  end

  local cmd = { "curl", "-fsSL", "--retry", "3", "--connect-timeout", "15" }
  vim.list_extend(cmd, args)

  local ok, job = pcall(vim.system, cmd, { text = true }, function(result)
    vim.schedule(function()
      local code = tonumber(result.code) or -1
      if code ~= 0 then
        callback(("curl failed with exit code %d: %s"):format(code, (result.stderr or ""):sub(1, 1000)))
        return
      end
      callback(nil, result)
    end)
  end)

  if not ok then
    callback("Could not start curl: " .. tostring(job))
  end
end

---@param cfg SpringAnalyzerConfig
---@param callback fun(err: string?, path: string?)
---@param force? boolean
function M.install(cfg, callback, force)
  if state.downloading then
    table.insert(state.queue, callback)
    return
  end

  local explicit, explicit_err = M.explicit_jar(cfg)
  if cfg.scanner.jar and cfg.scanner.jar ~= "" then
    if explicit then
      callback(nil, explicit)
    else
      callback(explicit_err)
    end
    return
  end

  local target = M.cached_path(cfg)

  if not force and vim.fn.filereadable(target) == 1 then
    if cfg.scanner.checksum then
      local ok = M.verify(target, cfg.scanner.checksum)
      if ok then
        callback(nil, target)
        return
      end
    else
      callback(nil, target)
      return
    end
  end

  local url = M.jar_url(cfg)
  if not url then
    callback("Invalid scanner.download_url; expected a URL template with %s placeholders")
    return
  end

  local dir = vim.fs.dirname(target)
  local ok_dir, dir_err = pcall(vim.fn.mkdir, dir, "p")
  if not ok_dir then
    callback("Could not create scanner directory: " .. tostring(dir_err))
    return
  end

  state.downloading = true
  state.queue = {}
  local part = target .. ".part"

  local function finish(err, path)
    state.downloading = false
    local queue = state.queue
    state.queue = {}

    callback(err, path)
    for _, queued in ipairs(queue) do
      queued(err, path)
    end
  end

  local function fail(message)
    pcall(uv.fs_unlink, part)
    finish(message)
  end

  local function verify_and_rename()
    local expected = cfg.scanner.checksum
    if expected then
      local ok, actual = M.verify(part, expected)
      if not ok then
        fail(("Checksum mismatch for %s (expected %s, got %s)"):format(url, expected, actual))
        return
      end
      local renamed, rename_err = uv.fs_rename(part, target)
      if not renamed then
        fail("Could not move downloaded JAR into place: " .. tostring(rename_err))
        return
      end
      notify(cfg, "scanner v" .. cfg.scanner.version .. " installed")
      finish(nil, target)
      return
    end

    local checksum_url = M.checksum_url(cfg, url)
    curl({ checksum_url }, function(checksum_err, result)
      if checksum_err then
        fail("Could not download checksum from " .. checksum_url .. ": " .. checksum_err)
        return
      end

      local expected_checksum = parse_checksum(result.stdout or "")
      if not expected_checksum then
        fail("Checksum file does not contain a valid SHA-256: " .. checksum_url)
        return
      end

      local ok, actual = M.verify(part, expected_checksum)
      if not ok then
        fail(("Checksum mismatch for %s (expected %s, got %s)"):format(
          url,
          expected_checksum,
          actual
        ))
        return
      end

      local renamed, rename_err = uv.fs_rename(part, target)
      if not renamed then
        fail("Could not move downloaded JAR into place: " .. tostring(rename_err))
        return
      end

      notify(cfg, "scanner v" .. cfg.scanner.version .. " installed")
      finish(nil, target)
    end)
  end

  notify(cfg, "downloading scanner v" .. cfg.scanner.version .. "...")
  curl({ "-o", part, url }, function(download_err)
    if download_err then
      fail("Could not download scanner JAR: " .. download_err)
      return
    end
    verify_and_rename()
  end)
end

---Ensure a JAR is available, downloading it only when necessary.
---@param cfg SpringAnalyzerConfig
---@param callback fun(err: string?, path: string?)
function M.ensure(cfg, callback)
  local explicit = M.explicit_jar(cfg)
  if cfg.scanner.jar and cfg.scanner.jar ~= "" then
    if explicit then
      schedule(callback, nil, explicit)
    else
      schedule(callback, "Configured scanner.jar does not exist: " .. cfg.scanner.jar)
    end
    return
  end

  local bundled = M.bundled_path()
  if vim.fn.filereadable(bundled) == 1 then
    schedule(callback, nil, bundled)
    return
  end

  local cached = M.cached_path(cfg)
  if vim.fn.filereadable(cached) == 1 then
    if cfg.scanner.checksum then
      local ok = M.verify(cached, cfg.scanner.checksum)
      if ok then
        schedule(callback, nil, cached)
        return
      end
    else
      schedule(callback, nil, cached)
      return
    end
  end

  if cfg.scanner.auto_download == false then
    schedule(callback, "Scanner JAR not found. Run :SpringAnalyzer install or configure scanner.jar")
    return
  end

  M.install(cfg, callback, true)
end

---@param cfg SpringAnalyzerConfig
---@param callback fun(major: integer?)
function M.java_version(cfg, callback)
  local ok, job = pcall(vim.system, { cfg.scanner.java or "java", "-version" }, { text = true }, function(result)
    vim.schedule(function()
      local text = (result.stderr or "") .. (result.stdout or "")
      local major = text:match('version "(%d+)') or text:match("(%d+)%.")
      callback(tonumber(major))
    end)
  end)

  if not ok then
    schedule(callback, nil)
  end
end

return M
