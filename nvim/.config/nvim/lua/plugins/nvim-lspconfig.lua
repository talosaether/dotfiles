return {
  "williamboman/mason.nvim",
  config = function()
    -- Setup mason for LSP server management
    require("mason").setup()

    -- Enable hyperlinks in LSP hover and signature help
    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
      vim.lsp.handlers.hover, {
        focusable = true,
        style = "minimal",
        border = "rounded",
      }
    )

    -- Global LSP settings
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

      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
      vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
      vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, opts)
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
      vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    end

    -- Setup LSP servers manually using vim.lsp.start
    local servers = {
      lua_ls = { cmd = { "lua-language-server" } },
      pyright = { cmd = { "pyright-langserver", "--stdio" } },
      ts_ls = { cmd = { "typescript-language-server", "--stdio" } },
      rust_analyzer = { cmd = { "rust-analyzer" } },
      bashls = { cmd = { "bash-language-server", "start" } }
    }

    for name, config in pairs(servers) do
      vim.api.nvim_create_autocmd("FileType", {
        pattern = name == "lua_ls" and "lua" or
                  name == "pyright" and "python" or
                  name == "ts_ls" and {"javascript", "typescript"} or
                  name == "rust_analyzer" and "rust" or
                  name == "bashls" and {"sh", "bash"} or nil,
        callback = function()
          vim.lsp.start(vim.tbl_extend("force", config, {
            name = name,
            capabilities = capabilities,
            on_attach = on_attach,
          }))
        end,
      })
    end
  end
}
