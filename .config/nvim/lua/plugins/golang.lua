
return  {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      {'lukas-reineke/lsp-format.nvim', config = true}
    },
    opts = {
      servers = {
        gopls = {
          on_init = function(client)
            -- Set the offset encoding during initialization
            client.offset_encoding = "utf-8"
          end,
        },
      },
      setup = {
        gopls = function()
          require("lazyvim.util").lsp.on_attach(function(client, buffnr)
            require('lsp-format').on_attach(client, buffnr)
          end)
        end,
      },
    },
  },
}
