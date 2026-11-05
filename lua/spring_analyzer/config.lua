local M = {}

---@class SpringAnalyzerConfig
---@field scanner SpringAnalyzerScannerConfig
---@field cache SpringAnalyzerCacheConfig
---@field auto SpringAnalyzerAutoConfig
---@field ui SpringAnalyzerUiConfig

---@class SpringAnalyzerScannerConfig
---@field java? string
---@field jar? string explicit JAR path; wins over auto-download
---@field version? string scanner version to download
---@field auto_download? boolean
---@field download_url? string URL template with two %s placeholders: version, version
---@field checksum_url? string optional checksum URL; defaults to <jar-url>.sha256
---@field checksum? string optional expected SHA-256
---@field include_tests? boolean
---@field include_mvc? boolean
---@field extra_args? string[]

---@class SpringAnalyzerCacheConfig
---@field dir? string
---@field max_age? number seconds; 0 means it never expires

---@class SpringAnalyzerAutoConfig
---@field on_save? boolean
---@field on_open? boolean
---@field debounce? number milliseconds

---@class SpringAnalyzerUiConfig
---@field notify? boolean
---@field picker? table

M.defaults = {
  scanner = {
    java = nil,
    jar = nil,
    version = "1.0.0",
    auto_download = true,
    download_url = "https://github.com/davidsoles/spring-analyzer/releases/download/v%s/spring-analyzer-%s.jar",
    checksum_url = nil,
    checksum = nil,
    include_tests = false,
    include_mvc = false,
    extra_args = {},
  },
  cache = {
    dir = nil,
    max_age = 300,
  },
  auto = {
    on_save = true,
    on_open = true,
    debounce = 750,
  },
  ui = {
    notify = true,
    picker = {
      title = "SpringAnalyzer Endpoints",
    },
  },
}

---@param opts? table
---@return SpringAnalyzerConfig
function M.setup(opts)
  local cfg = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  if not cfg.scanner.java or cfg.scanner.java == "" then
    cfg.scanner.java = vim.fn.exepath("java")
    if cfg.scanner.java == "" then
      cfg.scanner.java = "java"
    end
  end

  if cfg.scanner.jar and cfg.scanner.jar ~= "" then
    cfg.scanner.jar = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(cfg.scanner.jar), ":p"))
  end

  if cfg.cache.dir and cfg.cache.dir ~= "" then
    cfg.cache.dir = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(cfg.cache.dir), ":p"))
  end

  cfg.scanner.version = tostring(cfg.scanner.version or "1.0.0")

  return cfg
end

return M
