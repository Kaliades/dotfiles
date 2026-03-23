return {
  -- Dodanie pluginu Gruvbox Material
  {
    "sainnhe/gruvbox-material",
    lazy = false,
    priority = 1000,
    config = function()
      -- Opcjonalna konfiguracja przed załadowaniem motywu
      vim.g.gruvbox_material_background = "hard" -- Opcje: 'hard', 'medium', 'soft'
      vim.g.gruvbox_material_foreground = "original" -- Opcje: 'material', 'mix', 'original'
      vim.g.gruvbox_material_better_performance = 1
    end,
  },

  -- Ustawienie go jako domyślny motyw w LazyVim
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox-material",
    },
  },
}
