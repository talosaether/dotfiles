return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  config = function()
    require("nvim-treesitter").setup()

    require("nvim-treesitter").install({
      "lua", "python", "bash", "typescript", "javascript", "html", "css",
      "json", "yaml", "go", "markdown", "dockerfile", "markdown_inline",
      "c", "cpp", "vue", "svelte",
    })

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        if pcall(vim.treesitter.start, args.buf) then
          vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.wo.foldmethod = "expr"
        end
      end,
    })
  end,
}
