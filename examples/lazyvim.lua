-- Example LazyVim specification.
-- Copy this file to ~/.config/nvim/lua/plugins/spring-analyzer.lua
--
-- For local development, replace the GitHub URL with:
--   dir = "/home/dsoles/Neovim/spring-analyzer.nvim",
--   name = "spring-analyzer.nvim",
return {
  {
    "davidsoles/spring-analyzer.nvim",
    ft = "java",
    cmd = {
      "SpringAnalyzer",
      "SpringAnalyzerRefresh",
      "SpringAnalyzerClear",
      "SpringAnalyzerStatus",
      "SpringAnalyzerCancel",
      "SpringAnalyzerInstall",
      "SpringAnalyzerDoctor",
      "SpringEndpoints",
      "SpringEndpointsRefresh",
      "SpringEndpointsClear",
      "SpringEndpointsStatus",
      "SpringEndpointsCancel",
    },
    keys = {
      { "<leader>sa", "<cmd>SpringAnalyzer<cr>", desc = "SpringAnalyzer: endpoints" },
      { "<leader>sr", "<cmd>SpringAnalyzerRefresh<cr>", desc = "SpringAnalyzer: refresh" },
      { "<leader>sd", "<cmd>SpringAnalyzerDoctor<cr>", desc = "SpringAnalyzer: diagnostics" },
    },
    dependencies = {
      "folke/snacks.nvim",
    },
    opts = {
      scanner = {
        version = "1.0.0",
        auto_download = true,
        -- Local development override. If set, no download is attempted.
        -- jar = "/home/dsoles/Java/spring-analyzer/target/spring-analyzer-1.0.0.jar",
        include_tests = false,
        include_mvc = false,
      },
      cache = {
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
    },
    config = function(_, opts)
      require("spring_analyzer").setup(opts)
    end,
  },
}
