return {
  -- Plugin Catppuccin
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        telescope = true,
        treesitter = true,
        which_key = true,
        native_lsp = { enabled = true },
        mason = true,
        notify = true,
        mini = { enabled = true },
      },
    },
  },

  -- Ustawienie go jako domyślny motyw w LazyVim
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
