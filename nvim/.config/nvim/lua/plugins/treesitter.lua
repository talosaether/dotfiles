return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  lazy = false,
  config = function()
    ---@diagnostic disable-next-line: missing-fields
    require("nvim-treesitter").setup({
      ensure_installed = {
        "lua",
        "python",
        "bash",
        "typescript",
        "javascript",
        "html",
        "css",
        "json",
        "yaml",
        "go",
        "markdown",
        "dockerfile",
        "markdown_inline",
        "c",
        "cpp",
        "vue",
        "svelte",
      },
      auto_install = true,
      sync_install = false,
    })
    -- Incremental selection keymaps
    vim.keymap.set("n", "<CR>", function()
      require("nvim-treesitter.incremental_selection").init_selection()
    end, { desc = "Init treesitter selection" })
    vim.keymap.set("v", "<CR>", function()
      require("nvim-treesitter.incremental_selection").node_incremental()
    end, { desc = "Increment treesitter selection" })
    vim.keymap.set("v", "<TAB>", function()
      require("nvim-treesitter.incremental_selection").scope_incremental()
    end, { desc = "Increment treesitter scope" })
    vim.keymap.set("v", "<S-TAB>", function()
      require("nvim-treesitter.incremental_selection").node_decremental()
    end, { desc = "Decrement treesitter selection" })
  end,
}
