# neiljohari / dotfiles-local

Personal dotfiles for Neil Johari — macOS (Apple Silicon), zsh, tmux, Vim, iTerm2.

Layered on top of [`~/dotfiles`](https://github.com/neiljohari/dotfiles-base) (a forked-and-owned copy of [thoughtbot/dotfiles](https://github.com/thoughtbot/dotfiles)). Base provides the scaffolding; this repo (`~/dotfiles-local`) holds everything personal. Both are symlinked into `$HOME` by [`rcm`](https://github.com/thoughtbot/rcm).

---

## Bootstrap a fresh Mac

One command — `install.sh` is idempotent and safe to re-run:

```sh
# If the repos aren't cloned yet, do this two-step first:
git clone git@github.com:neiljohari/dotfiles-base.git   ~/dotfiles
git clone git@github.com:neiljohari/dotfiles.git        ~/dotfiles-local

# Then:
~/dotfiles-local/install.sh
```

What it does (each step is a `skip` if already done):

1. Ensures Xcode Command Line Tools
2. Ensures Homebrew
3. Clones both dotfiles repos (`~/dotfiles` and `~/dotfiles-local`) if missing
4. `brew bundle install --file=~/dotfiles-local/Brewfile` — formulae, casks, fonts, MAS apps
5. `rcup` — symlinks both repos into `$HOME`
6. Symlinks `~/.config/starship.toml` and `~/.config/mise/config.toml` into the tracked `config/` dir
7. `mise install` — pulls the pinned Node / Python / Ruby versions
8. `vim-plug` + `:PlugInstall` — installs vim plugins
9. `fzf` shell integration (`.fzf.zsh`)
10. `:CocInstall` for the coc extensions (solargraph, prettier, tsserver, eslint, json)
11. Points iTerm2 at `~/dotfiles-local/iterm/` for the preferences plist (if you've saved one)
12. Adds saved SSH keys to the macOS keychain

Post-install, one manual step you still have to do: **iTerm2 → Settings → Profiles → Text → Font → "FiraCode Nerd Font Mono"** (or trust that the saved iTerm2 prefs already set that — see below).

### Saving iTerm2 preferences into the repo

iTerm2 stores everything — profiles, fonts, key bindings, color schemes — in one plist. To make those bootstrap-able:

1. `~/dotfiles-local/iterm/` already exists (empty).
2. Open iTerm2 → **Settings → General → Preferences**.
3. Check **"Load preferences from a custom folder or URL"** and point it at `~/dotfiles-local/iterm/`.
4. Click **"Save Now"** — iTerm2 writes `com.googlecode.iterm2.plist` into that folder.
5. Leave **"Save changes: Automatically"** enabled if you want the repo to track prefs live.
6. `cd ~/dotfiles-local && git add iterm/ && git commit -m "Save iTerm2 preferences"`.

From then on, `install.sh` step 11 will auto-point a fresh Mac's iTerm2 at those preferences.

---

## The stack

| Layer               | Tool                                                                 |
| ------------------- | -------------------------------------------------------------------- |
| Terminal emulator   | iTerm2 (Ghostty installed as option — see `docs/REVAMP-2026.md`)     |
| Shell               | zsh                                                                  |
| Plugin manager      | [antidote](https://getantidote.github.io) (replaced antigen)         |
| Prompt              | [starship](https://starship.rs) (gruvbox-rainbow preset)             |
| Multiplexer         | tmux (prefix `C-s`, vim-aware split nav via `C-h/j/k/l`)             |
| Version manager     | [mise](https://mise.jdx.dev) — node, python, ruby, etc.              |
| Conda/mamba         | miniforge3, lazy-loaded (no startup tax)                             |
| File listing        | [eza](https://eza.rocks) (replaced exa)                              |
| Fuzzy finder        | fzf + fzf-tab for zsh tab-completion                                 |
| Find replacement    | [fd](https://github.com/sharkdp/fd)                                  |
| Cat replacement     | [bat](https://github.com/sharkdp/bat)                                |
| Jump to dirs        | [zoxide](https://github.com/ajeetdsouza/zoxide) — `z foo`            |
| Dir-local env       | [direnv](https://direnv.net)                                         |
| Git TUI             | [lazygit](https://github.com/jesseduffield/lazygit)                  |
| GitHub CLI          | [gh](https://cli.github.com)                                         |
| System monitor      | [btop](https://github.com/aristocratos/btop)                         |
| Editor              | Vim + coc.nvim (solargraph for Ruby). Neovim migration planned.      |
| ctags               | universal-ctags                                                      |
| Clipboard from tmux | `pbcopy` pipe on mouse-drag or `y` in copy-mode                      |

---

## Repo layout

```
~/dotfiles-local/
├── README.md                      (this file)
├── install.sh                     (idempotent bootstrap for a fresh Mac)
├── docs/
│   └── REVAMP-2026.md             (2026-04 modernization writeup)
├── Brewfile                       (formulae + casks + fonts + MAS apps)
├── Dockerfile.dev                 (legacy, unused)
├── aliases.local                  (eza/bat/btop aliases)
├── config/                        (symlinked into ~/.config by install.sh)
│   ├── starship.toml              (prompt)
│   └── mise/config.toml           (pinned language versions)
├── iterm/                         (iTerm2 preferences plist — save into here)
├── gitconfig.local                (gitconfig overrides)
├── gitignore                      (global gitignore)
├── ssh/config                     (ssh config — single Host *, ControlMaster)
├── tmux.conf.local                (tmux overrides — truecolor, mouse, copy)
├── tmuxline-generated.conf        (tmuxline snapshot, sourced by tmux.conf.local)
├── vim/coc-settings.json          (coc.nvim config — Ruby, TS, Prettier)
├── vimrc.bundles.local            (extra vim plugins: coc, gruvbox, vimspector, …)
├── vimrc.local                    (vim config — gruvbox, coc mappings, rspec, …)
├── zsh_plugins.txt                (antidote plugin manifest)
├── zshenv.local                   (PATH for non-interactive shells — Homebrew + cargo)
└── zshrc.local                    (interactive shell config — antidote, starship, mise, …)
```

`rcup` resolves `dotfiles-local/foo` → `~/.foo` (leading dot is added automatically).

---

## Extending the setup

### Add a shell plugin
Append a line to `zsh_plugins.txt` (`user/repo` form), then `antidote reset && exec zsh`.

### Add a new language
```sh
mise use -g go@latest
mise use -g rust@latest
```
mise writes to `~/.config/mise/config.toml`.

### Add a vim plugin
Append `Plug 'author/repo'` to `vimrc.bundles.local`, then in vim `:PlugInstall`.

### Change the prompt
Pick a new starship preset (`starship preset --list`), then:
```sh
starship preset nerd-font-symbols -o ~/.config/starship.toml
```
All presets except `plain-text-symbols` need a Nerd Font.

### Add per-project shell env
Put an `.envrc` file in the project, add `export SOMETHING=value`, then run `direnv allow`.

### Add a Brew formula
Append to `Brewfile`, then `brew bundle install --file=~/dotfiles-local/Brewfile`.

---

## Key bindings worth remembering

### tmux
| Binding                       | Action                                  |
| ----------------------------- | --------------------------------------- |
| `C-s` (prefix)                | All tmux commands                       |
| `C-h` / `C-l`                 | Prev / next window (no prefix)          |
| `C-h/j/k/l` inside tmux + vim | Seamless pane + split navigation        |
| prefix + `-` / `\`            | Split horizontally / vertically         |
| prefix + `b`                  | Break pane into new window              |
| prefix + `j`                  | Join pane from another session (prompt) |
| prefix + `s`                  | Swap pane (prompt)                      |
| prefix + `[`                  | Enter copy-mode                         |
| `v` in copy-mode              | Start selection                         |
| `y` in copy-mode              | Copy to system clipboard (pbcopy)       |
| Mouse drag                    | Select + copy to system clipboard       |

### zsh
| Binding / Command | Action                                       |
| ----------------- | -------------------------------------------- |
| `z foo`           | jump to frecent dir matching "foo" (zoxide)  |
| `lg`              | launch lazygit                               |
| `ll` / `la`       | `eza -lh --git` / `eza -lah --git`           |
| `grt`             | `cd $(git root)`                             |
| `direnv allow`    | approve an `.envrc` in this directory        |
| `tat`             | create-or-attach tmux session for this dir   |

### vim (leader = `<space>`)
| Mapping           | Action                            |
| ----------------- | --------------------------------- |
| `<leader>t/s/l/a` | RSpec: file / nearest / last / all |
| `<leader>db`      | Termdebug (gdb)                   |
| `gd gi gr gy`     | coc: def / impl / refs / type-def |
| `K`               | coc: show docs                    |
| `[g` / `]g`       | prev / next diagnostic            |
| `<leader>rn`      | coc: rename symbol                |
| `<leader>f`       | coc: format selected              |
| `ii` in insert    | `<Esc>`                           |
| `C-p`             | `:Files` (fzf)                    |
| `\`               | `:Ag` (prompt for pattern)        |

---

## Troubleshooting

- **`?` boxes in the prompt** → iTerm2 isn't using a Nerd Font. Fix in Settings → Profiles → Text → Font.
- **`compinit: no such file or directory`** after a brew change → `rm -f ~/.zcompdump* && exec zsh`.
- **Tmux copy still feels broken** → make sure you're on tmux 3.5+ (`brew upgrade tmux`). `set-clipboard on` was removed because tmux 3.3a crashes under heavy output.
- **Shell startup got slow again** → `zmodload zsh/zprof` at the top of `zshrc.local`, `zprof | head -30` at the bottom, open a new shell, read.
- **SSH asks for passphrase every time** → `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` once to store in macOS keychain.

---

## History

See [`docs/REVAMP-2026.md`](docs/REVAMP-2026.md) for the 2026-04 modernization that rebuilt this setup from a 2020-era thoughtbot fork.
