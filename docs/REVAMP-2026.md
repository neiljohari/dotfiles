# 2026-04 Dev Setup Revamp

This repo was originally a fork of [thoughtbot/dotfiles](https://github.com/thoughtbot/dotfiles) with local overrides under `~/dotfiles-local`. Over five years (last upstream sync 2020-12-09) the setup accumulated drift — broken plugins that silently no-op'd, paths pinned to Intel Homebrew, prompts forking 20 subprocesses per render, and a tmux config that disabled truecolor while claiming to enable it.

The 2026 revamp fixed all of that and brought the setup in line with modern tooling. This doc explains what changed and why.

---

## Measured wins

| Metric                               | Before  | After      |
| ------------------------------------ | ------- | ---------- |
| `zsh -i -c exit` (best of 3)         | ~1.5 s  | **~0.21 s**|
| Vim startup time                     | slow, with errors | clean, <100 ms |
| tmux copy causing server crash       | yes     | no         |
| "compinit: no such file" warnings    | on every shell | gone  |
| Claude CLI glitches inside tmux      | constant | gone       |
| Tracked-but-modified base files      | 5       | 0 (all in `.local`) |

---

## Root causes diagnosed

### `UnPlug 'w0rp/ale'` was a typo
The base `vimrc.bundles` declares `Plug 'dense-analysis/ale'` (the maintained fork). The local `UnPlug 'w0rp/ale'` pointed at the ancestor name that was never registered, so the UnPlug silently did nothing. **ALE and coc.nvim both loaded, each running lint+LSP on every keystroke.**

### `ccls` config pointed at removed Xcode 12 paths
`coc-settings.json` pinned ccls to an Xcode 12 clang path that hasn't existed in years, plus `-stdlib=libstdc++` which Apple removed from the macOS SDKs ages ago. Every `.c`/`.cpp` open threw errors at start.

### tmux truecolor never actually engaged
`default-terminal "screen-256color"` + `terminal-overrides ",xterm-256color:Tc"` — the override targeted a terminal name tmux wasn't reporting. Claude CLI, vim's gruvbox colorscheme, and anything color-heavy degraded to 256-color. Add missing `focus-events`, `mouse on`, zero escape-time, and you get the **copy-paste visual glitches and Claude flicker** the revamp started from.

### Shell startup bloat
- `antigen` + `oh-my-zsh` layered together — antigen is effectively unmaintained since 2019.
- Spaceship prompt with 20 language modules that forked subprocesses on **every render**.
- Synchronous `nvm.sh` source (~300 ms).
- `conda shell.zsh hook` subprocess (~500 ms) on every shell, even when conda wasn't used.
- `compinit` called twice (once in `zshrc.local`, once in `zsh/configs/post/completion.zsh`).
- `brew --prefix` forked every shell to locate `site-functions`.

### Intel-only paths on an ARM Mac
`/usr/local/opt/python/libexec/bin`, `/usr/local/opt/riscv-gnu-toolchain/bin`, `/usr/local/sbin`, `/usr/local/share/zsh/site-functions` were all still prepended to `PATH`/`FPATH`. Half were dead, the other half caused stale completion caches to reference removed Intel binaries — the source of the `compinit: no such file or directory: /usr/local/share/zsh/site-functions/_brew_cask` warning.

### Tracked-file edits in the base repo
`~/dotfiles/vimrc`, `zshrc`, `zshenv`, `git_template/info/exclude` had all been edited in place rather than via the `.local` override system. Any future `git pull upstream` would have produced merge conflicts.

---

## What was done

The revamp was split into 7 independently pickable phases.

### Phase 0 — Triage
Pure subtraction. No-risk removal of dead configs.
- Fixed `UnPlug 'dense-analysis/ale'` — ALE no longer double-loads with coc.
- Removed the ccls languageserver block from `coc-settings.json`.
- Removed the dead UltiSnips triggers (plugin wasn't installed).
- Removed the dead ALE config block from `vimrc.local`.
- Added ARM fzf path detection to `vimrc.bundles.local`.
- Guarded the base's `augroup ale` so missing `ale#Queue` doesn't throw on every CursorHold.

### Phase 1 — tmux
- `default-terminal "tmux-256color"`.
- `terminal-overrides ",*256col*:Tc,alacritty:Tc,xterm-ghostty:Tc"` — truecolor now works across iTerm2 / alacritty / ghostty.
- `set -s escape-time 10` — fixes ESC+key sequences (Alt+B etc. now work in Claude CLI) without introducing perceptible lag.
- `focus-events on` so vim's `FocusGained/FocusLost` hooks fire inside tmux.
- `mouse on`, `history-limit 100000`.
- Copy bindings: `v` starts selection, `y` pipes through `pbcopy`, mouse-drag does the same.
- **Deliberately did not enable** `set-clipboard on` / `allow-passthrough on` — tmux 3.3a crashes under heavy output (Claude CLI) with these enabled. Direct `pbcopy` works without them.

### Phase 2 — Detach the fork, restructure, SSH, Brewfile
- Renamed the `~/dotfiles` thoughtbot remote: `origin` → `upstream-thoughtbot`. Kept for cherry-picks if ever needed. Personal fork at `github:neiljohari/dotfiles-base` is the new intended origin.
- Folded all 5 tracked base-file edits into `.local`:
  - `~/dotfiles/git_template/info/exclude` `.worktrees/` → `~/dotfiles-local/gitignore`.
  - `~/dotfiles/vimrc` ALE guard → `augroup ale / autocmd!` in `vimrc.local` (wipes the base autocmds).
  - `~/dotfiles/vimrc.bundles` ARM fzf → `UnPlug 'junegunn/fzf'` + ARM `Plug` in `vimrc.bundles.local`.
  - `~/dotfiles/zshenv` `. "$HOME/.cargo/env"` → new `zshenv.local`.
  - `~/dotfiles/zshrc` conda/mamba/NVM/rvm/riscv → folded into `zshrc.local`.
- Removed the `zshenv` "you edited PATH" warning — we intentionally edit PATH in zshenv so non-interactive shells (SSH, Claude CLI) inherit Homebrew.
- Consolidated SSH: one `Host *` block with all four `IdentityFile`s, `ControlMaster auto` w/ `ControlPath ~/.ssh/cm-%r@%h:%p` (multiplexes SSH connections), `IdentitiesOnly yes`, `ServerAliveInterval 60`. **Removed wildcard `ForwardAgent yes`** — a security footgun that exposed your agent to every host you SSH'd into. Per-host opt-in pattern is in the comments.
- Brewfile:
  - Removed `homebrew/bundle`, `homebrew/cask`, `homebrew/cask-fonts`, `homebrew/core`, `homebrew/services` (all implicit since Homebrew 2.6).
  - Removed `python@3.9` (EOL), `gdb` (broken on ASi), `ctags` (dead upstream; replaced with `universal-ctags`), `exa` (archived 2023; replaced with `eza`), `nvm` (replaced with `mise`), `ccls` (we no longer use C/C++ LSP).
  - Added `eza`, `fd`, `zoxide`, `starship`, `direnv`, `lazygit`, `gh`, `mise`, `btop`, `universal-ctags`, `antidote`, `ghostty`, `font-fira-code-nerd-font`.

### Phase 3 — Shell rebuild
- **Plugin manager**: `antigen` + `oh-my-zsh` → [`antidote`](https://getantidote.github.io). Manifest in `~/dotfiles-local/zsh_plugins.txt`. Deleted the 58 KB vendored `antigen.zsh`.
- **Prompt**: `spaceship-prompt` → [`starship`](https://starship.rs), `gruvbox-rainbow` preset. Starship only runs language detectors when it sees project markers, so no per-render forking.
- **Version manager**: `nvm` / `rvm` / `pyenv` → [`mise`](https://mise.jdx.dev). Global config at `~/.config/mise/config.toml` pins `node@lts python@3.12 ruby@3.3`.
- **Conda/mamba**: were initialized synchronously; now **lazy-loaded** on first `conda`/`mamba` call. Miniforge is still the scientific Python stack, just no startup tax.
- Removed Intel `/usr/local/opt/python/libexec/bin` and `/usr/local/opt/riscv-gnu-toolchain/bin` from PATH.
- `zshrc.local` had its own `FPATH=$(brew --prefix)/...` + `compinit` block at the top — removed. Single compinit now runs in `zsh/configs/post/completion.zsh`, which we updated to also include the ARM `/opt/homebrew/share/zsh/site-functions` path.
- `$PATH += /opt/homebrew/bin:/opt/homebrew/sbin` moved from `zshrc.local` to `zshenv.local` so SSH subprocesses and the Claude CLI inherit Homebrew paths.
- Added `eval "$(zoxide init zsh)"` and `eval "$(direnv hook zsh)"`.

### Phase 4 — Modern CLI aliases
`aliases.local` wires:
```
ls    → eza --group-directories-first
ll    → eza -lh --group-directories-first --git
la    → eza -lah --group-directories-first --git
tree  → eza --tree --level=3
cat   → bat --paging=never
top   → btop
lg    → lazygit
```

### Phase 5 — Terminal emulator (installed, not adopted)
`ghostty` is in the Brewfile and the tmux `terminal-overrides` recognize `xterm-ghostty:Tc`. Still running on iTerm2 by default — Ghostty is a one-command swap when you want to try it.

### Phase 6 — Neovim migration (deferred)
Not started. Plan is in `~/.claude/plans/ultrareview-this-folder-and-fizzy-aho.md` if you want to pick it up: lazy.nvim + nvim-lspconfig + mason.nvim + blink.cmp + telescope + nvim-treesitter, keeping vim as a fallback during the transition.

---

## Files changed

### `~/dotfiles` (base)
3 edits after the restructure — all ARM-related:
- `zsh/configs/post/completion.zsh` — added `/opt/homebrew/share/zsh/site-functions` to fpath.
- `zsh/configs/post/path.zsh` — added `/opt/homebrew/sbin` before `/usr/local/sbin`.
- `zshenv` — removed the PATH-edit warning block (we intentionally edit PATH here).

### `~/dotfiles-local`
New files:
- `README.md` — entry-point docs.
- `docs/REVAMP-2026.md` — this file.
- `aliases.local` — modern CLI aliases.
- `zsh_plugins.txt` — antidote manifest.
- `zshenv.local` — Homebrew + cargo PATH for all shells.

Rewritten:
- `Brewfile` — 15 removed, 13 added.
- `gitignore` — added `.worktrees/`.
- `ssh/config` — 4 blocks → 1, dropped wildcard ForwardAgent.
- `tmux.conf.local` — truecolor, focus, mouse, `pbcopy` pipe.
- `vim/coc-settings.json` — removed ccls block + displayByAle.
- `vimrc.bundles.local` — fixed UnPlug, added ARM fzf detection.
- `vimrc.local` — removed dead ALE/UltiSnips blocks, added ALE autocmd wipe.
- `zshrc.local` — full rewrite: antidote / starship / mise / lazy conda / zoxide / direnv.

---

## User decisions locked in during the revamp

- **Detach fully from thoughtbot upstream** — own the fork; cherry-pick later if ever desired.
- **Rip out C/C++ LSP** — rarely write C/C++ anymore; don't need ccls keeping up with Xcode.
- **Keep tmux bindings** — `C-s` prefix, `C-h/C-l` window nav, vim-aware pane nav; these live in tmux so terminal swaps never affect them.
- **Stay on iTerm2 for now** — Ghostty installed as option; no forced migration.

---

## If you have to redo this on a new machine

See `install.sh` in the repo root. It runs `brew bundle`, rcups both dotfiles repos, installs mise languages, symlinks `~/.config` entries, points iTerm2 at the saved profile, and runs `:PlugInstall`. The README has a quickstart.
