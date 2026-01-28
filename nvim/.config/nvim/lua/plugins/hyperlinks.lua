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
    opts = {},
    cmd = "Trouble",
    keys = {
      { "<leader>tt", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>td", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics" },
      { "<leader>tq", "<cmd>Trouble quickfix toggle<cr>", desc = "Quickfix List" },
      { "<leader>tl", "<cmd>Trouble loclist toggle<cr>", desc = "Location List" },
      { "gR", "<cmd>Trouble lsp_references focus=true<cr>", desc = "LSP References" },
    },
  }
}