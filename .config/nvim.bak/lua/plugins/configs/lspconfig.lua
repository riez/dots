local present, lspconfig = pcall(require, "lspconfig")
local masonlsppresent, masonlspconfig = pcall(require, "mason-lspconfig")

if not present or not masonlsppresent then
  return
end

local M = {}
local utils = require "core.utils"

-- export on_attach & capabilities for custom lspconfigs

M.on_attach = function(client, bufnr)
  client.server_capabilities.documentFormattingProvider = false
  client.server_capabilities.documentRangeFormattingProvider = false

  utils.load_mappings("lspconfig", { buffer = bufnr })
end

M.capabilities = vim.lsp.protocol.make_client_capabilities()

M.capabilities.textDocument.completion.completionItem = {
  documentationFormat = { "markdown", "plaintext" },
  snippetSupport = true,
  preselectSupport = true,
  insertReplaceSupport = true,
  labelDetailsSupport = true,
  deprecatedSupport = true,
  commitCharactersSupport = true,
  tagSupport = { valueSet = { 1 } },
  resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  },
}

masonlspconfig.setup_handlers {
  -- default handler - setup with default settings
  function(server_name)
    lspconfig[server_name].setup {
      on_attach = M.on_attach,
      capabilities = M.capabilities,
    }
  end,
  -- overriden handler
  ["lua_ls"] = function()
    lspconfig.lua_ls.setup {
      on_attach = M.on_attach,
      capabilities = M.capabilities,

      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            library = {
              [vim.fn.expand "$VIMRUNTIME/lua"] = true,
              [vim.fn.expand "$VIMRUNTIME/lua/vim/lsp"] = true,
            },
            maxPreload = 100000,
            preloadFileSize = 10000,
          },
        },
      },
    }
  end,
  ["tailwindcss"] = function()
    lspconfig.tailwindCSS.setup {
      on_attach = M.on_attach,
      capabilities = M.capabilities,
      settings = {
        tailwindCSS = {
          experimental = {
            classRegex = {
              "(tailwind|clsx)\\('([^)]*)\\')",
              "'([^']*)'",
            },
          },
        },
      },
    }
  end,
}

return M
