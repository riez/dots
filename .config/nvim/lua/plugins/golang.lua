
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
          Snacks.util.lsp.on({ name = "gopls" }, function(buffer, client)
            require('lsp-format').on_attach(client, buffer)
          end)
        end,
      },
    },
  },
}
