return {
  "okuuva/auto-save.nvim",
  event = { "InsertLeave", "TextChanged" },
  opts = {
    enabled = true,
    trigger_events = {
      immediate_save = { "BufLeave", "FocusLost" },
      defer_save = { "InsertLeave", "TextChanged" },
      cancel_deferred_save = { "InsertEnter" },
    },
    debounce_delay = 500,
    condition = function(buf)
      local ft = vim.bo[buf].filetype
      -- auto-save tylko dla tego, co cię boli
      return vim.tbl_contains(
        { "css", "scss", "less", "html", "twig", "javascript", "javascriptreact", "typescript", "typescriptreact" },
        ft
      )
    end,
  },
}
