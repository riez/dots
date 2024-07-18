return {
  "nvim-telescope/telescope.nvim",

  dependencies = {
    {

      "debugloop/telescope-undo.nvim",
      keys = {
        { "<F5>", "<cmd>Telescope undo<cr>", mode = "n", desc = "Browse undo tree with Telescope" },
      },
    },
    {
      "nvim-telescope/telescope-frecency.nvim",
      keys = {
        { ";<leader>", "<cmd>Telescope frecency workspace=CWD<cr>", mode = "n", desc = "Recent (cwd)" },
        { "<leader>;", "<cmd>Telescope frecency<cr>", mode = "n", desc = "Recent" },
      },
    },
  },

  opts = {
    pickers = {
      find_files = {
        follow = true,
      },
      live_grep = {
        additional_args = { "-L" },
      },
    },
  },
}
