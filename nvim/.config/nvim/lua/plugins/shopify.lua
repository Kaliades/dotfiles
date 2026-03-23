return {
  -- Podświetlanie składni Liquid (tree-sitter)
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "liquid" },
    },
  },

  -- LSP dla Shopify Liquid (theme-check)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        theme_check = {},
      },
    },
  },
}
