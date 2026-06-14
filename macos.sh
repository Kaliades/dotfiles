#!/usr/bin/env bash
#
# macOS — ustawienia systemowe przez `defaults`.
# Odpalany ręcznie na świeżym Macu: `./install.sh macos` (albo `bash macos.sh`).
# To NIE jest config do stow — macOS trzyma ustawienia w bazie `defaults`,
# więc zamiast symlinka mamy skrypt, który tę bazę zapisuje.
#
# Sekcja "WIERNE" = zrzut z mojego maca (to, co faktycznie mam zmienione).
# Sekcja "QoL"    = rozsądne dodatki — odkomentuj/przytnij wedle uznania.

set -euo pipefail

echo ":: Ustawiam macOS defaults…"

# Zamknij Ustawienia systemowe, żeby nie nadpisały zmian przy zamknięciu
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

# ============================================================================
# WIERNE — Dock (główna customizacja)
# ============================================================================
defaults write com.apple.dock autohide -bool true                 # auto-ukrywanie
defaults write com.apple.dock tilesize -int 16                    # małe ikony
defaults write com.apple.dock magnification -bool true            # powiększanie po najechaniu
defaults write com.apple.dock largesize -int 30                   # rozmiar przy powiększeniu
defaults write com.apple.dock orientation -string "bottom"        # na dole
defaults write com.apple.dock show-recents -bool false            # bez ostatnich aplikacji
defaults write com.apple.dock minimize-to-application -bool false # minimalizacja jako osobny kafel

# Hot corner: prawy-dolny = Quick Note (14), bez modyfikatora
defaults write com.apple.dock wvous-br-corner -int 14
defaults write com.apple.dock wvous-br-modifier -int 0

# ============================================================================
# WIERNE — wygląd / Finder
# ============================================================================
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"  # tryb ciemny
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" # widok listy

# ============================================================================
# QoL — rozsądne dodatki (odkomentuj te, które chcesz)
# ============================================================================
# Szybsze powtarzanie klawiszy (świetne do nvim/terminala)
# defaults write NSGlobalDomain KeyRepeat -int 2
# defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Finder: pokazuj rozszerzenia, pasek ścieżki i statusu, foldery na górze
# defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# defaults write com.apple.finder ShowPathbar -bool true
# defaults write com.apple.finder ShowStatusBar -bool true
# defaults write com.apple.finder _FXSortFoldersFirst -bool true
# defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Screenshoty do ~/Screenshots zamiast na pulpit (utwórz katalog jeśli używasz)
# mkdir -p "$HOME/Screenshots"
# defaults write com.apple.screencapture location -string "$HOME/Screenshots"

# Trackpad: stuknięcie = kliknięcie
# defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
# defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# ============================================================================
# Restart procesów, żeby zmiany weszły od ręki
# ============================================================================
for app in Dock Finder SystemUIServer; do
  killall "$app" 2>/dev/null || true
done

echo ":: Gotowe. Niektóre zmiany wymagają wylogowania/restartu."
