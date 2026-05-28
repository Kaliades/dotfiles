# Zellij — ściąga keybindów

Otwarte przez `Alt + ?`. Zamknij: `q`.

## Globalne (działają wszędzie, poza locked)

| Skrót            | Akcja                            |
| ---------------- | -------------------------------- |
| `Alt h/j/k/l`    | Focus pane / sąsiedni tab        |
| `Alt n`          | Nowy pane                        |
| `Alt w`          | Zamknij pane                     |
| `Alt /`          | Toggle floating panes            |
| `Alt \`          | Nowy tab                         |
| `Alt , / Alt .`  | Poprzedni / następny tab         |
| `Alt + / Alt -`  | Resize +/-                       |
| `Alt [ / Alt ]`  | Prev / next swap layout          |
| `Alt i / Alt o`  | Przesuń tab w lewo / prawo       |
| `Alt s`          | Session manager (floating)       |
| `Alt c`          | Picker sesji Claude'a (cj)       |
| `Alt Shift /`    | **Ta ściąga**                    |
| `Ctrl g`         | Lock (tryb LOCKED)               |
| `Ctrl q`         | Quit                             |

## Wejście w tryby

| Skrót     | Tryb                                       |
| --------- | ------------------------------------------ |
| `Ctrl p`  | PANE   — operacje na panelach              |
| `Ctrl t`  | TAB    — operacje na tabach                |
| `Ctrl n`  | RESIZE — zmiana rozmiaru panelu            |
| `Ctrl h`  | MOVE   — przenoszenie panelu               |
| `Ctrl s`  | SCROLL — przewijanie / search w buforze    |
| `Ctrl o`  | SESSION — sesje, konfiguracja, pluginy     |
| `Ctrl b`  | TMUX   — kompatybilność z bindami tmuxa    |
| `Enter` / `Esc` | Wyjście z trybu do NORMAL            |

## PANE mode (`Ctrl p`)

| Klawisz  | Akcja                          |
| -------- | ------------------------------ |
| `h/j/k/l`| Focus w kierunku               |
| `n`      | Nowy pane                      |
| `d`      | Nowy pane w dół                |
| `r`      | Nowy pane w prawo              |
| `s`      | Nowy pane stacked              |
| `x`      | Zamknij focus                  |
| `c`      | Rename pane                    |
| `f`      | Toggle fullscreen              |
| `w`      | Toggle floating                |
| `e`      | Embed / floating toggle        |
| `i`      | Pin floating pane              |
| `z`      | Toggle ramki paneli            |
| `p`      | Switch focus                   |

## TAB mode (`Ctrl t`)

| Klawisz  | Akcja                          |
| -------- | ------------------------------ |
| `h/k`    | Poprzedni tab                  |
| `j/l`    | Następny tab                   |
| `1`-`9`  | Idź do taba #N                 |
| `n`      | Nowy tab                       |
| `x`      | Zamknij tab                    |
| `r`      | Rename tab                     |
| `s`      | Toggle sync (broadcast input)  |
| `b`      | Break pane do nowego taba      |
| `[ / ]`  | Break pane do tabu w lewo/prawo|
| `Tab`    | Toggle ostatni tab             |

## RESIZE mode (`Ctrl n`)

| Klawisz       | Akcja                     |
| ------------- | ------------------------- |
| `h/j/k/l`     | Zwiększ w kierunku        |
| `H/J/K/L`     | Zmniejsz w kierunku       |
| `+ / =`       | Zwiększ ogólnie           |
| `-`           | Zmniejsz ogólnie          |

## MOVE mode (`Ctrl h`)

| Klawisz       | Akcja                     |
| ------------- | ------------------------- |
| `h/j/k/l`     | Przenieś pane             |
| `n / Tab`     | Move (forward)            |
| `p`           | Move backwards            |

## SCROLL mode (`Ctrl s`)

| Klawisz       | Akcja                     |
| ------------- | ------------------------- |
| `j/k`         | Scroll down / up          |
| `h/l`         | Page up / down            |
| `Ctrl b/f`    | Page up / down            |
| `u/d`         | Half page up / down       |
| `s`           | Wejdź w search            |
| `e`           | Edytuj scrollback w `$EDITOR` |
| `Ctrl c`      | Skocz na dół + wyjście    |

W search: `n / p` next/prev, `c` case sensitivity, `w` wrap, `o` whole word.

## SESSION mode (`Ctrl o`)

| Klawisz | Akcja                         |
| ------- | ----------------------------- |
| `w`     | Session manager (floating)    |
| `d`     | Detach od sesji               |
| `c`     | Configuration plugin          |
| `l`     | Layout manager                |
| `p`     | Plugin manager                |
| `a`     | About                         |
| `s`     | Share session                 |

W session-managerze: ↑/↓ wybór, `Enter` attach, `Ctrl+r` rename, `fn+Delete` (Forward Delete) zabij sesję.

## TMUX mode (`Ctrl b`)

| Klawisz   | Akcja                        |
| --------- | ---------------------------- |
| `"`       | Nowy pane w dół              |
| `%`       | Nowy pane w prawo            |
| `c`       | Nowy tab                     |
| `n / p`   | Next / prev tab              |
| `h/j/k/l` | Focus i powrót do NORMAL     |
| `o`       | Focus next pane              |
| `z`       | Fullscreen                   |
| `,`       | Rename tab                   |
| `[`       | Wejdź w SCROLL               |
| `Space`   | Next swap layout             |
| `Ctrl b`  | Wyślij Ctrl+B do pane'a      |
