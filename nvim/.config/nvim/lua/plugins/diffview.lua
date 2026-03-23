return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Historia pliku" },
    { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Historia brancha" },
  },
}
