return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      { 'lukas-reineke/lsp-format.nvim', config = true }
    },
    opts = {
      servers = {
        tsserver = {
          typescript = {
            on_init = function(client)
              -- set the offset encoding during initialization
              client.offset_encoding = "utf-8"
            end,
          },
        },
        svelte = {},
        tailwindcss = {},
      },
      setup = {
        tsserver = function()
          require("lazyvim.util").lsp.on_attach(function(client, buffnr)
            require('lsp-format').on_attach(client, buffnr)
          end)
        end,
        svelte = function()
          require("lazyvim.util").lsp.on_attach(function(client, buffnr)
            require('lsp-format').on_attach(client, buffnr)
          end)
        end,
        tailwindcss = function()
          require("lazyvim.util").lsp.on_attach(function(client, buffnr)
            require('lsp-format').on_attach(client, buffnr)
          end)
        end
      },
    },
  },
}
