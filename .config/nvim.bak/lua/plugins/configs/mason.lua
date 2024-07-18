local present, mason = pcall(require, "mason")

if not present then
  return
end

vim.api.nvim_create_augroup("_mason", { clear = true })
vim.api.nvim_create_autocmd("Filetype", {
  pattern = "mason",
  callback = function()
    -- require("base46").load_highlight "mason"
  end,
  group = "_mason",
})

local options = {
  ensure_installed = {
    -- Lang-Server
    "lua-language-server",
    "typescript-language-server",
    "svelte-language-server",
    "tailwindcss-language-server",
    "eslint-lsp",
    "eslint_d",
    "css-lsp",
    "gopls",
    "pyright",
    "diagnostic-languageserver",
    "rust-analyzer",
    "sqlls",
    "dart-debug-adapter",
    -- Commented since conflicted with tsserver
    -- "deno",
    "solargraph",
    "kotlin-language-server",
    "kotlin-debug-adapter",
    "cmake-language-server",
    "graphql-language-service-cli",
    "vue-language-server",
    "yaml-language-server",
    "dockerfile-language-server",
    "elixir-ls",
    "cfn-lint",
    "smithy-language-server",
    -- -- Terraform
    "terraform-ls",
    "tflint",
    "tfsec",
    -- -- Formatter
    "gofumpt",
    "isort",
    "jq",
    "ktlint",
    "prettierd",
    "rubocop",
    "clang-format",
    "joker",
    "stylua",
    "rustfmt",
    "shfmt",
    "sql-formatter",
    "yamlfmt",
  }, -- not an option from mason.nvim

  PATH = "skip",

  ui = {
    icons = {
      package_pending = " ",
      package_installed = " ",
      package_uninstalled = " ﮊ",
    },

    keymaps = {
      toggle_server_expand = "<CR>",
      install_server = "i",
      update_server = "u",
      check_server_version = "c",
      update_all_servers = "U",
      check_outdated_servers = "C",
      uninstall_server = "X",
      cancel_installation = "<C-c>",
    },
  },

  max_concurrent_installers = 10,
}

options = require("core.utils").load_override(options, "williamboman/mason.nvim")

vim.api.nvim_create_user_command("MasonInstallAll", function()
  vim.cmd("MasonInstall " .. table.concat(options.ensure_installed, " "))
end, {})

mason.setup(options)
