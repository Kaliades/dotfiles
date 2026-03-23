return {
  -- Podświetlanie składni Liquid
  {
    "Shopify/tree-sitter-liquid",
    build = ":TSUpdate liquid",
  },

  -- Rejestracja parsera tree-sitter dla Liquid
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
