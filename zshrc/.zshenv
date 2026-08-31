# ============================================================================
# .zshenv — źródłowany przez KAŻDY zsh (także nieinteraktywny i nie-login).
# Trzymamy tu wyłącznie to, co musi zadziałać przy `ssh host <komenda>` —
# reszta środowiska siedzi w .zshrc.
# ============================================================================

# Toolchain rustupa (cargo, rustc, a na Linuksie także binarka `zellij`) — rustup
# trzyma je w ~/.cargo/bin i dostarcza własny skrypt ustawiający PATH. Guard robi
# z tego no-op tam, gdzie rustupa nie ma (na macOS te narzędzia idą z brew), a sam
# skrypt jest idempotentny — przy wielokrotnym źródłowaniu nie duplikuje wpisu.
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# SSH agent na maszynach zdalnych (na macOS launchd ogarnia agenta sam):
# stabilna ścieżka do forwardowanego socketu, żeby shelle w długo żyjącej sesji
# multipleksera (Zellij, herdr) przeżywały reconnect — SSH_AUTH_SOCK zmienia się
# przy każdym logowaniu, a serwer sesji zamraża swoją wartość przy starcie.
# Świeży login ma żywy socket → odświeża symlink; shell w sesji ma martwą starą
# wartość → warunek nie przechodzi i tylko przestawia się na symlink.
#
# DLACZEGO .zshenv, A NIE .zshrc: `herdr --remote` nie robi interaktywnego loginu —
# odpala serwer i sondy przez `ssh <target> <komenda>`, czyli nieinteraktywny,
# nie-login shell, który źródłuje TYLKO ten plik. To jedyne miejsce na tej ścieżce
# widzące żywy socket; panele herdra (interaktywne) mają już tylko martwą wartość,
# więc gdyby fix został w .zshrc, symlink nikt by nie odświeżył i `ssh-add -l`
# w panelu zwracał „Error connecting to agent". Zellij tego nie ujawniał, bo tam
# zawsze najpierw jest `ssh vibe` (login shell → .zshrc).
if [[ -n "$SSH_CONNECTION" ]]; then
  if [[ -n "$SSH_AUTH_SOCK" && -S "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$HOME/.ssh/ssh_auth_sock" ]]; then
    ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
  fi
  export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
fi
