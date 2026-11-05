local M = {}

local util = require("spring_analyzer.util")

local METHOD_HL = {
  GET = "DiagnosticInfo",
  POST = "DiagnosticOk",
  PUT = "DiagnosticWarn",
  PATCH = "DiagnosticWarn",
  DELETE = "DiagnosticError",
  HEAD = "Comment",
  OPTIONS = "Comment",
  ANY = "Title",
}

---@param root string
---@param endpoint table
---@return table
local function item_for(root, endpoint)
  local line = tonumber(endpoint.line) or 1
  local relative = endpoint.file or ""
  local file = util.join(root, relative)

  local text = string.format(
    "%-7s %-50s %s  %s:%d",
    endpoint.httpMethod or "?",
    endpoint.path or "",
    endpoint.handler or "",
    relative,
    line
  )

  return {
    text = text,
    spring = endpoint,
    file = file,
    pos = { line, 0 },
  }
end

---@param item table
---@return table
local function format(item)
  local endpoint = item.spring or {}
  local method = endpoint.httpMethod or "?"

  return {
    { string.format("%-7s", method), METHOD_HL[method] or "Title" },
    { " " },
    { endpoint.path or "", "String" },
    { " " },
    { endpoint.handler or "", "Comment" },
    { " " },
    { (endpoint.file or "") .. ":" .. tostring(endpoint.line or 0), "SnacksPickerFile" },
  }
end

---@param picker table
---@param item table
local function confirm(picker, item)
  picker:close()
  if not item then
    return
  end

  vim.schedule(function()
    vim.cmd("edit " .. vim.fn.fnameescape(item.file))
    local line = math.max(1, math.min(tonumber(item.pos[1]) or 1, vim.api.nvim_buf_line_count(0)))
    pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
    vim.cmd("normal! zz")
  end)
end

---Show endpoints with the snacks.nvim picker.
---@param root string
---@param endpoints table[]
---@param cfg SpringAnalyzerConfig
function M.show(root, endpoints, cfg)
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker or not snacks.picker.pick then
    vim.notify("spring-analyzer: snacks.nvim is not available", vim.log.levels.ERROR)
    return
  end

  local items = {}
  for _, endpoint in ipairs(endpoints or {}) do
    items[#items + 1] = item_for(root, endpoint)
  end

  snacks.picker.pick({
    title = (cfg and cfg.ui and cfg.ui.picker and cfg.ui.picker.title) or "SpringAnalyzer Endpoints",
    items = items,
    format = format,
    preview = "file",
    confirm = confirm,
    show_empty = true,
  })
end

return M
