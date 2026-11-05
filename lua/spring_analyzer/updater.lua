local M = {}

local uv = vim.uv or vim.loop

local RELEASES_URL = "https://api.github.com/repos/davidsoles/spring-analyzer/releases/latest"
local CACHE_VERSION = 1

---@param cfg SpringAnalyzerConfig
---@return string
function M.cache_path(cfg)
  local dir = (cfg and cfg.cache and cfg.cache.dir) or (vim.fn.stdpath("cache") .. "/spring-analyzer")
  return vim.fs.joinpath(dir, "update-check.json")
end

---@param cfg SpringAnalyzerConfig
---@return table?
local function read_cache(cfg)
  local file = io.open(M.cache_path(cfg), "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" or data.schemaVersion ~= CACHE_VERSION then
    return nil
  end
  return data
end

---@param cfg SpringAnalyzerConfig
---@param data table
local function write_cache(cfg, data)
  local path = M.cache_path(cfg)
  local dir = vim.fs.dirname(path)
  vim.fn.mkdir(dir, "p")

  local tmp = path .. ".tmp." .. vim.fn.getpid()
  local file = io.open(tmp, "w")
  if not file then
    return
  end
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    file:close()
    os.remove(tmp)
    return
  end
  file:write(encoded)
  file:close()
  uv.fs_rename(tmp, path)
end

---@param version string
---@return integer[]
function M.parts(version)
  local parts = {}
  local text = tostring(version or ""):gsub("^v", "")
  for number in text:gmatch("%d+") do
    parts[#parts + 1] = tonumber(number)
  end
  return parts
end

---@param latest string
---@param current string
---@return boolean
function M.is_newer(latest, current)
  local a = M.parts(latest)
  local b = M.parts(current)
  local size = math.max(#a, #b)
  for index = 1, size do
    local left = a[index] or 0
    local right = b[index] or 0
    if left ~= right then
      return left > right
    end
  end
  return false
end

---@param url string
---@param callback fun(err: string?, data: table?)
local function fetch_release(callback)
  if vim.fn.executable("curl") ~= 1 then
    callback("curl is required to check for scanner updates")
    return
  end

  local cmd = {
    "curl",
    "-fsSL",
    "--retry",
    "2",
    "--connect-timeout",
    "10",
    "-H",
    "Accept: application/vnd.github+json",
    "-H",
    "User-Agent: spring-analyzer.nvim",
    RELEASES_URL,
  }

  local ok, job = pcall(vim.system, cmd, { text = true }, function(result)
    vim.schedule(function()
      local code = tonumber(result.code) or -1
      if code ~= 0 then
        callback(("GitHub release check failed (%d): %s"):format(
          code,
          (result.stderr or ""):sub(1, 300)
        ))
        return
      end

      local decoded, data = pcall(vim.json.decode, result.stdout or "")
      if not decoded or type(data) ~= "table" or not data.tag_name then
        callback("GitHub release check returned an invalid response")
        return
      end

      callback(nil, {
        version = tostring(data.tag_name):gsub("^v", ""),
        tag = data.tag_name,
        url = data.html_url,
        checked_at = os.time(),
      })
    end)
  end)

  if not ok then
    callback("Could not start curl: " .. tostring(job))
  end
end

---Fetch the latest scanner release, using a short-lived on-disk cache.
---@param cfg SpringAnalyzerConfig
---@param callback fun(err: string?, data: table?)
---@param force? boolean bypass the cache
function M.fetch(cfg, callback, force)
  local cached = read_cache(cfg)
  local ttl = tonumber(cfg.scanner.update_check_ttl) or 86400

  if not force and cached and cached.checked_at and (os.time() - cached.checked_at) < ttl then
    vim.schedule(function()
      callback(nil, cached)
    end)
    return
  end

  fetch_release(function(err, data)
    if err then
      callback(err)
      return
    end
    data.schemaVersion = CACHE_VERSION
    write_cache(cfg, data)
    callback(nil, data)
  end)
end

return M
