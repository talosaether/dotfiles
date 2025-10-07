return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- pretty icons (optional):
    -- "nvim-tree/nvim-web-devicons",
  },
  cmd = "Telescope",
  keys = function()
    local safe_telescope = function(builtin_func)
      return function()
        if vim.fn.getcmdwintype() ~= "" then
          vim.notify("Can't open Telescope from command-line window", vim.log.levels.WARN)
          return
        end
        builtin_func()
      end
    end

    return {
      { "<leader>tf", safe_telescope(function() require("telescope.builtin").find_files() end), desc = "Find files" },
      { "<leader>tg", safe_telescope(function() require("telescope.builtin").live_grep() end), desc = "Live grep" },
      { "<leader>tb", safe_telescope(function() require("telescope.builtin").buffers() end), desc = "Buffers" },
      { "<leader>th", safe_telescope(function() require("telescope.builtin").help_tags() end), desc = "Help" },

      -- LSP navigation with hyperlinks
      { "<leader>ld", safe_telescope(function() require("telescope.builtin").lsp_definitions() end), desc = "LSP definitions" },
      { "<leader>li", safe_telescope(function() require("telescope.builtin").lsp_implementations() end), desc = "LSP implementations" },
      { "<leader>lr", safe_telescope(function() require("telescope.builtin").lsp_references() end), desc = "LSP references" },
      { "<leader>ls", safe_telescope(function() require("telescope.builtin").lsp_document_symbols() end), desc = "Document symbols" },
      { "<leader>lw", safe_telescope(function() require("telescope.builtin").lsp_workspace_symbols() end), desc = "Workspace symbols" },
    }
  end,
  config = function()
    require("telescope").setup({
      defaults = {
        -- This filters filenames in many pickers, but NOT the search operation itself.
        file_ignore_patterns = { "node_modules", "dist", "coverage", "build", "%.min%.js" },
        -- This controls what ripgrep actually searches.
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--hidden",              -- still see hidden files if not ignored
          "-g", "!node_modules/**",
          "-g", "!dist/**",
          "-g", "!coverage/**",
          "-g", "!build/**",
          "-g", "!.git/**",
          "-g", "!venv/**",
          "-g", "!.venv/**",
        },
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
