---@diagnostic disable: undefined-global
return {
  {
    "ellisonleao/gruvbox.nvim",
    config = function()
      -- Optionally configure and load the colorscheme
      -- directly inside the plugin declaration.
      vim.g.gruvbox_material_enable_italic = true
      -- vim.g.gruvbox_material_better_performance = 1
      vim.g.gruvbox_material_foreground = "original"
      vim.g.gruvbox_material_background = "hard"
      vim.g.gruvbox_material_enable_bold = true
      vim.g.gruvbox_material_transparent_background = 0
      vim.cmd("set background=light")
    end,
  },
  { "rebelot/kanagawa.nvim", opts = {
    transparent = true,
  } },
  { "projekt0n/github-nvim-theme", options = {
    transparent = true,
  } },
  { "sainnhe/gruvbox-material" },
  { "sainnhe/everforest" },

  -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox-material",
    },
  },
}
