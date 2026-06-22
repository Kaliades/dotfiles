return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
          auto_close = true,
        },
        files = {
          hidden = true,
          ignored = true,
          exclude = { ".git", "build", "node_modules", "out", ".nuxt", ".react-router", ".shopify", "var", "public" },
        },
        grep = {
          hidden = true,
          ignored = true,
          exclude = { ".git", "build", "node_modules", "out", ".nuxt", ".react-router", ".shopify", "var", "public" },
        },
      },
    },
  },
}
