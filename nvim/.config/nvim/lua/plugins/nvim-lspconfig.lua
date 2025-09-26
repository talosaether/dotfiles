return {
  "neovim/nvim-lspconfig",
  dependencies = {
    {
      "williamboman/mason.nvim",
      opts = {}
    },
    "williamboman/mason-lspconfig.nvim"
  },
  config = function()
    -- Setup mason-lspconfig
    require("mason-lspconfig").setup({
      ensure_installed = {
        "lua_ls",
        "pyright",
        "ts_ls", -- Updated from tsserver
        "rust_analyzer"
        -- gopls removed - requires Go to be installed
      },
      automatic_installation = true,
    })

    -- Enable hyperlinks in LSP hover and signature help
    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
      vim.lsp.handlers.hover, {
        -- Enable hyperlinks in hover windows
        focusable = true,
        style = "minimal",
        border = "rounded",
      }
    )

    -- Global LSP settings for hyperlink support
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.documentSymbol = {
      dynamicRegistration = true,
      symbolKind = {
        valueSet = vim.lsp.protocol.SymbolKind
      }
    }

    -- LSP keymaps for navigation
    local on_attach = function(client, bufnr)
      local opts = { buffer = bufnr, silent = true }

      -- Go to definition (creates hyperlinks)
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
      vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
      vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, opts)

      -- Hover and signature help
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
      vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    end

    -- Configure common language servers using new vim.lsp.config API
    local servers = { "lua_ls", "pyright", "ts_ls", "rust_analyzer" }
    for _, server in ipairs(servers) do
      vim.lsp.config(server, {
        capabilities = capabilities,
        on_attach = on_attach,
      })
    end
  end
}
