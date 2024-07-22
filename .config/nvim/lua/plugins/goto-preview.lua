return {
  "rmagatti/goto-preview",
  event = "BufEnter",
  config = true, -- necessary as per https://github.com/rmagatti/goto-preview/issues/88
  opts = {
    border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
    default_mappings = true,
    resizing_mappings = true,
    post_open_hook = function(_, winid)
      vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(winid, false)
      end)
    end,
  },
}
