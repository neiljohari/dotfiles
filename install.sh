#!/usr/bin/env bash
# Bootstrap this dotfiles setup on a fresh Mac.
#
# Safe to re-run: every step is idempotent (skip-if-installed / ln -sf / rcup).
# See README.md for the per-step rationale.

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
LOCAL="${LOCAL:-$HOME/dotfiles-local}"

say() { printf "\n\033[1;36m==>\033[0m %s\n" "$*"; }
skip() { printf "    \033[2m(skip) %s\033[0m\n" "$*"; }

# ─── 1. Xcode CLI tools ────────────────────────────────────────────────────
if ! xcode-select -p >/dev/null 2>&1; then
  say "Installing Xcode Command Line Tools"
  xcode-select --install
  echo "After the GUI installer finishes, re-run this script."
  exit 0
else
  skip "Xcode Command Line Tools already present"
fi

# ─── 2. Homebrew ───────────────────────────────────────────────────────────
if ! command -v brew >/dev/null 2>&1; then
  say "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apple Silicon vs Intel
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# ─── 3. Clone dotfiles repos ───────────────────────────────────────────────
if [ ! -d "$DOTFILES" ]; then
  say "Cloning base dotfiles into $DOTFILES"
  git clone git@github.com:neiljohari/dotfiles-base.git "$DOTFILES"
else
  skip "$DOTFILES exists"
fi

if [ ! -d "$LOCAL" ]; then
  say "Cloning local dotfiles into $LOCAL"
  git clone git@github.com:neiljohari/dotfiles.git "$LOCAL"
else
  skip "$LOCAL exists"
fi

# ─── 4. Install Brew packages from Brewfile ────────────────────────────────
say "Installing Homebrew packages (brew bundle)"
brew bundle install --file="$LOCAL/Brewfile"

# ─── 5. Symlink dotfiles via rcm ───────────────────────────────────────────
say "rcup: symlinking dotfiles into \$HOME"
RCRC="$DOTFILES/rcrc" rcup -f
rcup -d "$LOCAL" -f

# ─── 6. Symlink ~/.config entries that aren't managed by rcm ───────────────
say "Linking ~/.config entries"
mkdir -p "$HOME/.config/mise"
ln -sf "$LOCAL/config/starship.toml" "$HOME/.config/starship.toml"
ln -sf "$LOCAL/config/mise/config.toml" "$HOME/.config/mise/config.toml"
mkdir -p "$HOME/.config/ghostty"
ln -sf "$LOCAL/config/ghostty/config" "$HOME/.config/ghostty/config"

# ─── 7. Install mise-managed languages ─────────────────────────────────────
say "Installing mise languages"
mise install

# ─── 8. Install vim plugins ────────────────────────────────────────────────
if [ ! -d "$HOME/.vim/autoload/plug.vim" ] && [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
  say "Installing vim-plug"
  curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
say "Running :PlugInstall"
vim -E -s -u "$HOME/.vimrc" +PlugInstall +qall || true

# ─── 9. fzf shell integration ──────────────────────────────────────────────
if [ ! -f "$HOME/.fzf.zsh" ]; then
  say "Installing fzf shell integration"
  "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc
fi

# ─── 10. coc.nvim extensions ───────────────────────────────────────────────
say "Installing coc.nvim extensions (python, typescript, terraform, ruby, eslint, prettier, json)"
vim -E -s -u "$HOME/.vimrc" \
  +'CocInstall -sync coc-pyright coc-tsserver coc-eslint coc-prettier coc-terraform coc-solargraph coc-json' \
  +qall || true

# ─── 11. iTerm2 profile ────────────────────────────────────────────────────
if [ -f "$LOCAL/iterm/com.googlecode.iterm2.plist" ]; then
  say "Pointing iTerm2 at $LOCAL/iterm for profile/preferences"
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$LOCAL/iterm"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  echo "    Restart iTerm2 so it picks up the preferences."
else
  skip "No iTerm2 plist saved yet (see 'Saving iTerm2 preferences' in README.md)"
fi

# ─── 12. macOS keychain-backed SSH key ─────────────────────────────────────
for key in id_ed25519 id_rsakuberjew edamame_appserver terraform_ansible_bootstrap; do
  if [ -f "$HOME/.ssh/$key" ]; then
    ssh-add --apple-use-keychain "$HOME/.ssh/$key" 2>/dev/null || true
  fi
done

# ─── 13. tmuxline regenerate (optional) ────────────────────────────────────
# :Tmuxline lightline → :TmuxlineSnapshot ~/dotfiles-local/tmuxline-generated.conf
# (needs to run inside an interactive vim — skipped in bootstrap)

say "Done. Open a new iTerm2 window (or 'exec zsh') to enter the new shell."
echo ""
echo "Follow-up checklist:"
echo "  1. iTerm2 → Settings → Profiles → Text → Font → \"FiraCode Nerd Font Mono\""
echo "  2. If this is a fresh Mac, sign into GitHub (gh auth login) and GPG keys"
echo "  3. Verify shell startup: /usr/bin/time zsh -i -c exit  (expect ~0.2s)"
