return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      -- Enable hyperlinks in git blame and hover
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = 'eol',
        delay = 1000,
        ignore_whitespace = false,
      },
    }
  },
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      -- Enable hyperlinks in diagnostics and references
      auto_open = false,
      auto_close = true,
      use_diagnostic_signs = true,
    },
    keys = {
      { "<leader>tt", "<cmd>TroubleToggle<cr>", desc = "Toggle Trouble" },
      { "<leader>td", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Document Diagnostics" },
      { "<leader>tq", "<cmd>TroubleToggle quickfix<cr>", desc = "Quickfix List" },
      { "<leader>tl", "<cmd>TroubleToggle loclist<cr>", desc = "Location List" },
      { "gR", "<cmd>TroubleToggle lsp_references<cr>", desc = "LSP References" },
    },
  }
}