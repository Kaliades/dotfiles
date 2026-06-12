-- Motyw nvim: ręczny, lokalny przełącznik spójny z Ghostty — BEZ trybu jasny/ciemny macOS.
--
-- Stan trzyma plik ~/.config/theme-mode (POZA repo — per-urządzenie, nie leci do gita)
-- z nazwą colorscheme, np. "gruvbox" albo "catppuccin-mocha". Zmienia go skrypt
-- ~/.local/bin/theme, który równolegle przepisuje ~/.config/ghostty-theme.local i
-- przeładowuje Ghostty. nvim czyta plik na starcie (VimEnter, po LazyVim) i pollinguje
-- co 2 s, więc otwarte instancje przełączają się same po odpaleniu skryptu.

local THEME_FILE = vim.fn.expand("~/.config/theme-mode")
local DEFAULT = "catppuccin-mocha"
local uv = vim.uv or vim.loop

local function desired_scheme()
  local f = io.open(THEME_FILE, "r")
  if not f then
    return DEFAULT
  end
  local line = f:read("*l")
  f:close()
  line = line and line:gsub("%s+", "") or ""
  return line ~= "" and line or DEFAULT
end

local function start_watch()
  local current
  local function apply()
    local s = desired_scheme()
    if s == current then
      return
    end
    if pcall(vim.cmd.colorscheme, s) then
      current = s
    end
  end
  -- VimEnter biegnie PO tym jak LazyVim ustawi swój colorscheme → nasz wybór wygrywa bez flasha
  vim.api.nvim_create_autocmd("VimEnter", { callback = apply })
  -- poll: przełącza otwarte nvimy, gdy skrypt `theme` zmieni plik-stan
  local timer = uv.new_timer()
  timer:start(2000, 2000, vim.schedule_wrap(apply))
end

return {
  -- Plugin Catppuccin (motyw "nocny" — miększy, po ciemku)
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

  -- Plugin Gruvbox (motyw "dzienny" — hard contrast, spójny z Ghostty "Gruvbox Dark Hard")
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      contrast = "hard", -- hard, soft, lub "" (medium)
    },
    config = function(_, opts)
      require("gruvbox").setup(opts)
      start_watch() -- motywy załadowane → odpalamy watcher pliku-stanu
    end,
  },

  -- Baseline LazyVim (zanim watcher ustawi właściwy motyw — bez flasha tokyonight)
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
