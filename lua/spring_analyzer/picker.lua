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
  local file = relative ~= "" and util.join(root, relative) or nil

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
    preview = file and "file" or { text = text },
  }
end

---@param item table
---@return table
local function endpoint_format(item)
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
  if not item or not item.file then
    return
  end

  vim.schedule(function()
    vim.cmd("edit " .. vim.fn.fnameescape(item.file))
    local line = math.max(1, math.min(tonumber(item.pos[1]) or 1, vim.api.nvim_buf_line_count(0)))
    pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
    vim.cmd("normal! zz")
  end)
end

---@param root string
---@param relative string?
---@param line integer?
---@return string?, table?
local function file_pos(root, relative, line)
  if not relative or relative == "" then
    return nil, nil
  end
  return util.join(root, relative), { math.max(1, tonumber(line) or 1), 0 }
end

---@param items table[]
---@param item table
---@param parent? table
local function add_item(items, item, parent)
  item.parent = parent
  if parent then
    parent.children = parent.children or {}
    table.insert(parent.children, item)
  end
  items[#items + 1] = item
  return item
end

---@param item table
local function mark_last(item)
  local children = item.children or {}
  for index, child in ipairs(children) do
    child.last = index == #children
    mark_last(child)
  end
end

---@param root string
---@param event table
---@return table
local function event_item(root, event)
  local file, pos = file_pos(root, event.file, event.line)
  local label = event.eventSimpleName or event.eventType or "<unknown>"
  return {
    kind = "event",
    event = event,
    label = label,
    text = table.concat({
      label,
      event.eventType or "",
      event.file or "",
    }, " "),
    file = file,
    pos = pos,
    preview = file and "file" or { text = "Event: " .. label },
  }
end

---@param root string
---@param event table
---@param publisher? table
---@return table
local function publisher_item(root, event, publisher)
  if not publisher then
    local origin = event.publisherOrigin or "none"
    local label
    local kind
    local preview

    if origin == "framework" then
      label = "Spring Boot lifecycle"
      kind = "publisher"
      preview = "Published by the Spring Boot lifecycle"
    elseif origin == "external" then
      label = "external publisher (outside repository)"
      kind = "publisher"
      preview = "Published outside this repository"
    else
      label = "(no publisher found)"
      kind = "empty"
      preview = "No publisher found for " .. (event.eventSimpleName or "event")
    end

    return {
      kind = kind,
      origin = origin,
      label = label,
      text = table.concat({
        event.eventSimpleName or "",
        label,
        origin,
      }, " "),
      preview = { text = preview },
    }
  end

  local file, pos = file_pos(root, publisher.file, publisher.line)
  local label = publisher.handler or "<unknown>"
  return {
    kind = "publisher",
    event = event,
    publisher = publisher,
    label = label,
    text = table.concat({
      event.eventSimpleName or "",
      label,
      publisher.expression or "",
      publisher.receiverType or "",
      publisher.file or "",
    }, " "),
    file = file,
    pos = pos,
    preview = file and "file" or { text = "Publisher: " .. label },
  }
end

---@param root string
---@param event table
---@param listener? table
---@return table
local function listener_item(root, event, listener)
  if not listener then
    return {
      kind = "empty",
      label = "(no subscribers found)",
      text = (event.eventSimpleName or "") .. " no subscribers",
      preview = { text = "No subscribers found for " .. (event.eventSimpleName or "event") },
    }
  end

  local file, pos = file_pos(root, listener.file, listener.line)
  local label = listener.handler or "<unknown>"
  return {
    kind = "listener",
    event = event,
    listener = listener,
    label = label,
    text = table.concat({
      event.eventSimpleName or "",
      label,
      listener.annotation or "",
      listener.file or "",
    }, " "),
    file = file,
    pos = pos,
    preview = file and "file" or { text = "Subscriber: " .. label },
  }
end

---@param root string
---@param events table[]
---@return table[]
local function event_items(root, events)
  local items = {}

  for _, event in ipairs(events or {}) do
    local root_item = add_item(items, event_item(root, event))
    local publishers = event.publishers or {}
    local listeners = event.listeners or {}

    if #publishers == 0 and #listeners == 0 then
      add_item(items, {
        kind = "empty",
        label = "(no publishers or subscribers)",
        text = (event.eventSimpleName or "") .. " no publishers subscribers",
        preview = { text = "No publishers or subscribers for " .. (event.eventSimpleName or "event") },
      }, root_item)
    elseif #publishers == 0 then
      local parent = add_item(items, publisher_item(root, event, nil), root_item)
      for _, listener in ipairs(listeners) do
        add_item(items, listener_item(root, event, listener), parent)
      end
    else
      for _, publisher in ipairs(publishers) do
        local parent = add_item(items, publisher_item(root, event, publisher), root_item)
        if #listeners == 0 then
          add_item(items, listener_item(root, event, nil), parent)
        else
          for _, listener in ipairs(listeners) do
            add_item(items, listener_item(root, event, listener), parent)
          end
        end
      end
    end
  end

  for _, item in ipairs(items) do
    if item.parent == nil then
      mark_last(item)
    end
  end

  return items
end

---@param item table
---@param picker table
---@param snacks table
---@return table
local function event_format(item, picker, snacks)
  local highlights = {}
  if snacks.picker.format and snacks.picker.format.tree then
    vim.list_extend(highlights, snacks.picker.format.tree(item, picker))
  end

  if item.kind == "event" then
    local event = item.event or {}
    table.insert(highlights, { "◆ ", "Title" })
    table.insert(highlights, { item.label, "Title" })
    table.insert(highlights, {
      string.format("  (%d pub, %d sub)", #(event.publishers or {}), #(event.listeners or {})),
      "Comment",
    })
  elseif item.kind == "publisher" then
    local prefix = "PUB  "
    local highlight = "DiagnosticInfo"
    if item.origin == "framework" then
      prefix = "BOOT "
      highlight = "Special"
    elseif item.origin == "external" then
      prefix = "EXT  "
      highlight = "Comment"
    end
    table.insert(highlights, { prefix, highlight })
    table.insert(highlights, { item.label, "Function" })
    if item.publisher and item.publisher.expression and item.publisher.expression ~= "" then
      table.insert(highlights, { "  " .. item.publisher.expression, "Comment" })
    end
  elseif item.kind == "listener" then
    table.insert(highlights, { "SUB  ", "DiagnosticOk" })
    table.insert(highlights, { item.label, "String" })
    if item.listener and item.listener.annotation then
      table.insert(highlights, { "  " .. item.listener.annotation, "Comment" })
    end
  else
    table.insert(highlights, { item.label or "", "Comment" })
  end

  return highlights
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
    format = endpoint_format,
    preview = "preview",
    confirm = confirm,
    show_empty = true,
  })
end

---Show events as a publisher -> subscriber tree.
---@param root string
---@param events table[]
---@param cfg SpringAnalyzerConfig
function M.show_events(root, events, cfg)
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker or not snacks.picker.pick then
    vim.notify("spring-analyzer: snacks.nvim is not available", vim.log.levels.ERROR)
    return
  end

  snacks.picker.pick({
    title = "SpringAnalyzer Events",
    items = event_items(root, events),
    format = function(item, picker)
      return event_format(item, picker, snacks)
    end,
    preview = "preview",
    confirm = confirm,
    matcher = { keep_parents = true },
    show_empty = true,
  })
end

return M
