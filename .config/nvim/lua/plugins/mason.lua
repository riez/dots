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
        -- Go Related,
        "golangci-lint",
        "goimports",
        "goimports-reviser",
        -- Others
        "actionlint",
        "circleci-yaml-language-server",
        "gitlab-ci-ls",
        "docker-compose-language-service",
        "yaml-language-server",
        "yamllint",
        "yamlfmt",
        "yq",
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
        yamlls = {}
      },
      setup = {
        lua_ls = function()
          require("lazyvim.util").lsp.on_attach(function(client, buffnr)
            require('lsp-format').on_attach(client, buffnr)
          end)
        end,
        yamlls = function()
          require("lazyvim.util").lsp.on_attach(function(client, buffnr)
            require('lsp-format').on_attach(client, buffnr)
          end)
        end,
      },
    },

  }
}
