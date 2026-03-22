#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME"

# ============================================================================
# Kolory
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================================
# Helpers
# ============================================================================
info()  { echo -e "${CYAN}${BOLD}::${RESET} $1"; }
ok()    { echo -e "${GREEN}${BOLD}✓${RESET} $1"; }
warn()  { echo -e "${YELLOW}${BOLD}!${RESET} $1"; }
err()   { echo -e "${RED}${BOLD}✗${RESET} $1"; }

check_dep() {
  if ! command -v "$1" &>/dev/null; then
    err "$1 nie znaleziony. Zainstaluj: ${BOLD}brew install $1${RESET}"
    exit 1
  fi
}

# Pobierz listę pakietów (katalogi z pominięciem ukrytych i samego skryptu)
get_packages() {
  find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d \
    ! -name '.*' \
    -exec basename {} \; | sort
}

# Sprawdź czy pakiet jest już zastowowany (czy istnieje symlink wskazujący na nasze repo)
is_stowed() {
  local pkg="$1"
  local found=false
  while IFS= read -r -d '' file; do
    local rel="${file#$DOTFILES_DIR/$pkg/}"
    local target="$TARGET_DIR/$rel"
    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == *"$DOTFILES_DIR/$pkg"* ]]; then
      found=true
      break
    fi
  done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)
  $found
}

# ============================================================================
# Komendy
# ============================================================================
cmd_stow() {
  check_dep stow
  check_dep fzf

  local packages
  packages=$(get_packages)

  # Buduj listę z oznaczeniem statusu
  local items=()
  while IFS= read -r pkg; do
    if is_stowed "$pkg"; then
      items+=("$pkg  [zainstalowany]")
    else
      items+=("$pkg")
    fi
  done <<< "$packages"

  info "Wybierz pakiety do zainstalowania (TAB = zaznacz, ENTER = potwierdź):"
  echo ""

  local selected
  selected=$(printf '%s\n' "${items[@]}" \
    | fzf --multi \
          --header="󰒓  stow → $TARGET_DIR" \
          --prompt="instaluj> " \
          --marker="✓" \
          --border=rounded \
          --height=~50% \
          --reverse \
    | sed 's/  \[zainstalowany\]//' \
  ) || { info "Anulowano."; exit 0; }

  echo ""
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    info "Stow: ${BOLD}$pkg${RESET}"
    if stow -v -d "$DOTFILES_DIR" -t "$TARGET_DIR" "$pkg" 2>&1; then
      ok "$pkg zainstalowany"
    else
      err "$pkg — błąd podczas stow (może konflikt plików?)"
    fi
  done <<< "$selected"
}

cmd_unstow() {
  check_dep stow
  check_dep fzf

  local packages
  packages=$(get_packages)

  # Pokaż tylko zainstalowane pakiety
  local installed=()
  while IFS= read -r pkg; do
    if is_stowed "$pkg"; then
      installed+=("$pkg")
    fi
  done <<< "$packages"

  if [[ ${#installed[@]} -eq 0 ]]; then
    warn "Brak zainstalowanych pakietów."
    exit 0
  fi

  info "Wybierz pakiety do odinstalowania (TAB = zaznacz, ENTER = potwierdź):"
  echo ""

  local selected
  selected=$(printf '%s\n' "${installed[@]}" \
    | fzf --multi \
          --header="󰩺  unstow ← $TARGET_DIR" \
          --prompt="odinstaluj> " \
          --marker="✗" \
          --border=rounded \
          --height=~50% \
          --reverse \
  ) || { info "Anulowano."; exit 0; }

  echo ""
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    info "Unstow: ${BOLD}$pkg${RESET}"
    if stow -v -D -d "$DOTFILES_DIR" -t "$TARGET_DIR" "$pkg" 2>&1; then
      ok "$pkg odinstalowany"
    else
      err "$pkg — błąd podczas unstow"
    fi
  done <<< "$selected"
}

cmd_status() {
  local packages
  packages=$(get_packages)

  info "Status pakietów:\n"
  while IFS= read -r pkg; do
    if is_stowed "$pkg"; then
      echo -e "  ${GREEN}●${RESET} $pkg"
    else
      echo -e "  ${RED}○${RESET} $pkg"
    fi
  done <<< "$packages"
  echo ""
  echo -e "  ${GREEN}●${RESET} = zainstalowany   ${RED}○${RESET} = niezainstalowany"
}

cmd_help() {
  echo -e "${BOLD}dotfiles install${RESET} — zarządzanie konfiguracją przez GNU Stow\n"
  echo -e "Użycie: ${CYAN}./install.sh <komenda>${RESET}\n"
  echo -e "Komendy:"
  echo -e "  ${BOLD}stow${RESET}      Zainstaluj wybrane pakiety (symlinki do \$HOME)"
  echo -e "  ${BOLD}unstow${RESET}    Odinstaluj wybrane pakiety"
  echo -e "  ${BOLD}status${RESET}    Pokaż status wszystkich pakietów"
  echo -e "  ${BOLD}help${RESET}      Wyświetl tę pomoc"
}

# ============================================================================
# Main
# ============================================================================
case "${1:-help}" in
  stow)    cmd_stow ;;
  unstow)  cmd_unstow ;;
  status)  cmd_status ;;
  help|*)  cmd_help ;;
esac
