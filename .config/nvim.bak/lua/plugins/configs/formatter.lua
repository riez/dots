local present, formatter = pcall(require, "formatter")

if not present then
  return
end

local util = require "formatter.util"

local prettierd = function()
  return {
    exe = "prettierd",
    args = { vim.api.nvim_buf_get_name(0) },
    stdin = true,
  }
end

local function format_dart()
  return {
    exe = "/opt/homebrew/bin/dart", -- find with `which dart`
    args = { "format", vim.api.nvim_buf_get_name(0) },
    stdin = false,
    ignore_exitcode = true,
  }
end

local options = {
  -- Enable or disable logging
  logging = true,
  -- Set the log level
  log_level = vim.log.levels.WARN,
  filetype = {
    lua = {
      require("formatter.filetypes.lua").stylua,
      function()
        -- Supports conditional formatting
        if util.get_current_buffer_file_name() == "special.lua" then
          return nil
        end

        -- Full specification of configurations is down below and in Vim help
        -- files
        return {
          exe = "stylua",
          args = {
            "--search-parent-directories",
            "--stdin-filepath",
            util.escape_path(util.get_current_buffer_file_path()),
            "--",
            "-",
          },
          stdin = true,
        }
      end,
    },
    svelte = {
      require("formatter.filetypes.svelte").prettier,
      -- prettierd
      prettierd(),
    },
    javascript = {
      require("formatter.filetypes.javascript").prettierd,
      -- prettierd
      prettierd(),
    },
    javascriptreact = {
      require("formatter.filetypes.javascriptreact").prettierd,
      -- prettierd
      prettierd(),
    },
    typescript = {
      require("formatter.filetypes.typescript").prettierd,
      -- prettierd
      prettierd(),
    },
    typescriptreact = {
      require("formatter.filetypes.typescriptreact").prettierd,
      -- prettierd
      prettierd(),
    },
    dart = {
      format_dart(),
    },
  },
}

formatter.setup(options)
