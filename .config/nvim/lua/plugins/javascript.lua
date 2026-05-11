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
          Snacks.util.lsp.on({ name = "tsserver" }, function(buffer, client)
            require('lsp-format').on_attach(client, buffer)
          end)
        end,
        svelte = function()
          Snacks.util.lsp.on({ name = "svelte" }, function(buffer, client)
            require('lsp-format').on_attach(client, buffer)
          end)
        end,
        tailwindcss = function()
          Snacks.util.lsp.on({ name = "tailwindcss" }, function(buffer, client)
            require('lsp-format').on_attach(client, buffer)
          end)
        end
      },
    },
  },
}
