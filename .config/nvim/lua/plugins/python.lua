return {
  -- Add `server` and setup lspconfig
  {
    "neovim/nvim-lspconfig",
    dependencies = {},
    opts = {
      servers = {
        pyright = {
          python = {
            analysis = {
              autoSearchPaths = true,
              diagnosticMode = "workspace",
              useLibraryCodeForTypes = true,
            },
          },
        },
      },
      setup = {
        pyright = function()
          Snacks.util.lsp.on({ name = "pyright" }, function(buffer, client)
            require('lsp-format').on_attach(client, buffer)
            -- disable hover in favor of jedi-language-server
            client.server_capabilities.hoverProvider = false
          end)
        end,
      },
    },
  },
}
