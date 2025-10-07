return {
  "nvim-tree/nvim-tree.lua",
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },

  -- put your mappings here so they run *after* the plugin is available
  keys = {
    { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Toggle File Explorer" },
    {
      "<leader>m",
      function()
        local path = vim.api.nvim_buf_get_name(0)
        if path == "" then
          vim.notify("No file on disk for this buffer.", vim.log.levels.WARN)
          return
        end
        -- Try the API; if it's not ready for any reason, fall back to commands.
        local ok, api = pcall(require, "nvim-tree.api")
        if ok and api and api.tree then
          api.tree.open()
          if api.tree.find_file then
            -- newer API: accept opts (buf/open/focus/etc.)
            api.tree.find_file({ buf = 0, open = true, focus = true })
          else
            -- rare/older plugin: command fallback
            vim.cmd("NvimTreeFindFile")
            vim.cmd("NvimTreeFocus")
          end
        else
          -- ultimate fallback: commands (also work if lazy-loaded by cmd)
          vim.cmd("NvimTreeOpen")
          vim.cmd("NvimTreeFindFile")
          vim.cmd("NvimTreeFocus")
        end
      end,
      desc = "NvimTree: Reveal current file",
      silent = true,
    },
  },

  config = function()
    -- Remove background color from the NvimTree window (ui fix)
    -- vim.cmd([[hi NvimTreeNormal guibg=NONE ctermbg=NONE]])

    require("nvim-tree").setup({
      filters = { dotfiles = false },
      view = { adaptive_size = true },
      -- optional: keep tree synced to current file as you jump around
      update_focused_file = { enable = true, update_root = false },
      hijack_netrw = true,
    })
  end,
}

