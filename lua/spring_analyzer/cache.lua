local M = {}

local uv = vim.uv or vim.loop
local VERSION = 1

---@param cfg SpringAnalyzerConfig
---@return string
local function cache_dir(cfg)
  if cfg and cfg.cache and cfg.cache.dir and cfg.cache.dir ~= "" then
    return cfg.cache.dir
  end
  return vim.fn.stdpath("cache") .. "/spring-analyzer"
end

---@param root string
---@param cfg SpringAnalyzerConfig
---@return string
function M.path(root, cfg)
  local hash = vim.fn.sha256(root):sub(1, 16)
  return cache_dir(cfg) .. "/" .. hash .. ".json"
end

---@param root string
---@param cfg SpringAnalyzerConfig
---@return table?
function M.read(root, cfg)
  local path = M.path(root, cfg)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" then
    return nil
  end

  if data.version ~= VERSION or data.root ~= root or type(data.endpoints) ~= "table" then
    return nil
  end

  return data
end

---Write atomically (tmp + rename) so a partial cache is never left behind.
---@param root string
---@param data table
---@param cfg SpringAnalyzerConfig
---@return boolean?, string?
function M.write(root, data, cfg)
  local path = M.path(root, cfg)
  local dir = vim.fs.dirname(path)

  local ok_dir, dir_err = pcall(vim.fn.mkdir, dir, "p")
  if not ok_dir then
    return nil, dir_err
  end

  local tmp = path .. ".tmp." .. vim.fn.getpid()
  local file, open_err = io.open(tmp, "w")
  if not file then
    return nil, open_err
  end

  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    file:close()
    os.remove(tmp)
    return nil, encoded
  end

  file:write(encoded)
  file:close()

  local renamed, rename_err = uv.fs_rename(tmp, path)
  if not renamed then
    os.remove(tmp)
    return nil, rename_err
  end

  return true
end

---@param root string
---@param cfg SpringAnalyzerConfig
---@return boolean?, string?
function M.delete(root, cfg)
  local path = M.path(root, cfg)
  local ok, err = uv.fs_unlink(path)
  if not ok and err and not tostring(err):match("ENOENT") then
    return nil, err
  end
  return true
end

---Delete every SpringAnalyzer cache entry.
---@param cfg SpringAnalyzerConfig
---@return boolean?, string?
function M.clear_all(cfg)
  local dir = cache_dir(cfg)
  local handle = uv.fs_scandir(dir)
  if not handle then
    return true
  end

  while true do
    local name, typ = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if (typ == "file" or typ == nil) and (name:match("%.json$") or name:match("%.json%.tmp%.")) then
      uv.fs_unlink(dir .. "/" .. name)
    end
  end

  return true
end

---@param data table?
---@param cfg SpringAnalyzerConfig
---@return boolean
function M.is_stale(data, cfg)
  if not data or not data.generated_at then
    return true
  end

  local max_age = cfg and cfg.cache and cfg.cache.max_age or 0
  if max_age and max_age > 0 and (os.time() - data.generated_at) >= max_age then
    return true
  end

  local jar = data.scanner and data.scanner.jar
  if jar and jar ~= "" then
    local stat = uv.fs_stat(jar)
    if not stat then
      return true
    end
    if data.scanner.jar_mtime and stat.mtime and stat.mtime.sec ~= data.scanner.jar_mtime then
      return true
    end
  end

  return false
end

M.VERSION = VERSION

return M
