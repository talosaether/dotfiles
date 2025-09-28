return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "williamboman/mason.nvim"
  },
  config = function()
    -- Setup mason first
    require("mason").setup()

    local lspconfig = require("lspconfig")

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

    -- Manually setup each server
    local servers = { "lua_ls", "pyright", "ts_ls", "rust_analyzer", "bashls" }
    for _, server in ipairs(servers) do
      lspconfig[server].setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })
    end
  end
}
