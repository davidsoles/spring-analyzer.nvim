local M = {}

local GIT_MARKERS = { ".git" }
local BUILD_MARKERS = {
  "pom.xml",
  "mvnw",
  "gradlew",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  "settings.gradle.kts",
}

---Detect the project root from a buffer or the current working directory.
---@param buf? integer
---@param opts? { fallback?: boolean, markers?: string[] }
---@return string?
function M.root(buf, opts)
  opts = opts or {}
  buf = buf or 0

  local name = ""
  if vim.api.nvim_buf_is_valid(buf) then
    name = vim.api.nvim_buf_get_name(buf)
  end

  local start = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()

  local markers = opts.markers or BUILD_MARKERS
  local root = vim.fs.root(start, GIT_MARKERS)
    or vim.fs.root(start, markers)
    or vim.fs.root(vim.fn.getcwd(), GIT_MARKERS)
    or vim.fs.root(vim.fn.getcwd(), markers)

  if not root and opts.fallback then
    root = vim.fn.getcwd()
  end

  if not root then
    return nil
  end

  return vim.fs.normalize(root)
end

---@param path string
---@return boolean
function M.is_absolute(path)
  return path:sub(1, 1) == "/" or path:match("^%a:[/\\]") ~= nil
end

---Join a relative path with the project root.
---@param root string
---@param path string
---@return string
function M.join(root, path)
  if M.is_absolute(path) then
    return vim.fs.normalize(path)
  end
  return vim.fs.normalize(vim.fs.joinpath(root, path))
end

---@param buf? integer
---@return boolean
function M.is_java(buf)
  return vim.bo[buf or 0].filetype == "java"
end

return M
