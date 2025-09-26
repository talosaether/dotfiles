return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- pretty icons (optional):
    -- "nvim-tree/nvim-web-devicons",
  },
  cmd = "Telescope",
  keys = {
    { "<leader>tf", function() require("telescope.builtin").find_files() end, desc = "Find files" },
    { "<leader>tg", function() require("telescope.builtin").live_grep() end,  desc = "Live grep"  },
    { "<leader>tb", function() require("telescope.builtin").buffers() end,    desc = "Buffers"    },
    { "<leader>th", function() require("telescope.builtin").help_tags() end,  desc = "Help"       },

    -- LSP navigation with hyperlinks
    { "<leader>ld", function() require("telescope.builtin").lsp_definitions() end, desc = "LSP definitions" },
    { "<leader>li", function() require("telescope.builtin").lsp_implementations() end, desc = "LSP implementations" },
    { "<leader>lr", function() require("telescope.builtin").lsp_references() end, desc = "LSP references" },
    { "<leader>ls", function() require("telescope.builtin").lsp_document_symbols() end, desc = "Document symbols" },
    { "<leader>lw", function() require("telescope.builtin").lsp_workspace_symbols() end, desc = "Workspace symbols" },
  },
  config = function()
    require("telescope").setup({
      defaults = {
        mappings = {
          i = {
            ["<C-u>"] = false,
            ["<C-d>"] = false,
          },
        },
        -- Search more files including hidden ones
        file_ignore_patterns = {
          "%.git/",  -- Still ignore .git directory
          "node_modules/",
        },
      },
      pickers = {
        live_grep = {
          additional_args = function(opts)
            return {"--hidden", "--no-ignore-vcs"}
          end
        },
        find_files = {
          find_command = {"rg", "--files", "--hidden", "--no-ignore-vcs", "--glob", "!.git/*"}
        }
      }
    })
  end,
}
