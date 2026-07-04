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
        theme_check = {
          -- Default cmd (theme-check-language-server) nie istnieje jako binarka
          -- i mason nie ma dla niego mapowania — serwer dostarcza Shopify CLI
          -- (brew "shopify", jest w Brewfile).
          cmd = { "shopify", "theme", "language-server" },
          mason = false,
        },
      },
    },
  },
}
