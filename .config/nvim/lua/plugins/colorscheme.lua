return {
  { "ellisonleao/gruvbox.nvim" },
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
      colorscheme = "github_dark_default",
    },
  },
}
