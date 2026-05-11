-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Safely delete mappings that may not exist in newer LazyVim versions
pcall(vim.keymap.del, { 'x', 'n' }, 'gp')
pcall(vim.keymap.del, { 'x', 'n' }, 'gP')
