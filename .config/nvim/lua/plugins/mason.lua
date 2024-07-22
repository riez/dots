return {
  -- Ensure Installed
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- JS Related
        "prettierd",
        "eslint_d",
        "prettier",
        -- Writing Related
        "proselint",
        "alex",
        "write-good",
        -- Python Related
        "black",
        "pyright",
        "debugpy",
      },
    },
  },
  -- Lua Related
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      { 'lukas-reineke/lsp-format.nvim', config = true }
    },
    opts = {
      servers = {
        lua_ls = {
        },
      },
      setup = {
        lua_ls = function()
          require("lazyvim.util").lsp.on_attach(function(client, buffnr)
            require('lsp-format').on_attach(client, buffnr)
          end)
        end,
      },
    },

  }
}
