-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.timeoutlen = 1000
vim.opt.ttimeoutlen = 0
vim.opt.clipboard = "unnamed"

-- Root detection: prioritize cwd, then lsp, then .git
-- This prevents using parent git repos when opening non-git folders
vim.g.root_spec = { "cwd", "lsp", { ".git", "lua" } }
