#!/usr/bin/env bash
# Bootstrap a fresh Debian/Ubuntu, Arch, Fedora, or macOS machine. See README.md.
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPTIONAL=false
DRY_RUN=false

# Release binaries and install scripts land in ~/.local/bin, which a fresh
# machine doesn't have on PATH yet.
export PATH="$HOME/.local/bin:$PATH"

for arg in "$@"; do
  case "$arg" in
    --optional)
      OPTIONAL=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--optional] [--dry-run]

  --optional   also install optional apps (Ghostty, paru, opencode)
  --dry-run    show what would be installed for this machine, without installing
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

confirm() {
  # Read from /dev/tty so prompts work when the script is piped into bash.
  # With no terminal at all, accept.
  local reply
  printf '\033[1;36m??\033[0m %s [Y/n] ' "$*"
  if ! read -r reply 2>/dev/null </dev/tty; then
    printf 'y (no tty)\n'
    return 0
  fi
  case "$reply" in
    [nN]|[nN][oO]) return 1 ;;
    *) return 0 ;;
  esac
}

skip() { log "Skipping $1"; }

FAILED=()

run_step() {
  local desc="$1"; shift
  "$@" || { warn "Step failed: $desc (continuing)"; FAILED+=("$desc"); }
  return 0
}

OS=""
PM=""
FONT_DIR=""
ARCH=""
RUST_ARCH=""
RUST_PLATFORM=""
GO_PLATFORM=""

detect_os() {
  if [ "$(uname -s)" = Darwin ]; then
    OS=macos PM=brew
  elif [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
      *arch*|*manjaro*) OS=arch PM=pacman ;;
      *fedora*|*rhel*) OS=fedora PM=dnf ;;
      *debian*|*ubuntu*) OS=debian PM=apt-get ;;
    esac
  fi

  if [ -z "$OS" ]; then
    warn "Unsupported or undetected OS. See README.md for manual installation."
    exit 1
  fi

  if $DRY_RUN; then
    log "Detected OS: $OS (package manager: $PM)"
    return 0
  fi
  if ! confirm "Detected OS: $OS. Use $PM as the package manager?"; then
    warn "Aborted. Nothing was installed."
    exit 1
  fi
}

plan() { printf '  %-24s %s\n' "$1" "$2"; }

plan_tool() {
  local bin="$1" name="$2" method="$3"
  if have "$bin"; then
    plan "$name" "already installed"
  else
    plan "$name" "$method"
  fi
}

dry_run_plan() {
  local native="native package ($PM)"

  log "Dry run, nothing will be installed. Plan for this machine:"
  plan "base packages" "git zsh tmux stow figlet ... via $PM"
  if pm_tracks_upstream; then
    plan_tool nvim neovim "$native"
    plan_tool fzf fzf "$native"
    plan_tool rg ripgrep "$native"
    plan_tool fd fd "$native"
    plan_tool bat bat "$native"
    plan_tool zoxide zoxide "$native"
  else
    plan_tool nvim neovim "GitHub release -> /opt/nvim"
    plan_tool fzf fzf "GitHub release -> ~/.local/bin"
    plan_tool rg ripgrep "GitHub release -> ~/.local/bin"
    plan_tool fd fd "GitHub release -> ~/.local/bin"
    plan_tool bat bat "GitHub release -> ~/.local/bin"
    plan_tool zoxide zoxide "official install script"
  fi
  case "$OS" in
    arch|macos) plan_tool starship starship "$native" ;;
    *) plan_tool starship starship "official install script -> ~/.local/bin" ;;
  esac

  if font_installed; then
    plan "JetBrains Mono NF" "already installed"
  elif [ "$OS" = arch ]; then
    plan "JetBrains Mono NF" "$native: ttf-jetbrains-mono-nerd"
  else
    plan "JetBrains Mono NF" "GitHub release zip -> $FONT_DIR"
  fi

  if $OPTIONAL; then
    case "$OS" in
      macos)
        plan Ghostty "brew cask"
        ;;
      arch)
        plan_tool ghostty Ghostty "$native"
        plan_tool paru paru "AUR (makepkg)"
        ;;
      *)
        plan Ghostty "no official package, manual install"
        ;;
    esac
    plan_tool opencode opencode "opencode.ai install script"
  else
    plan "optional apps" "skipped (re-run with --optional to include)"
  fi

  plan "dotfiles" "stow -> $HOME (conflicting files backed up first)"
  if [ -d "$HOME/.config/tmux/plugins/tpm" ]; then
    plan "tmux plugins" "tpm already present"
  else
    plan "tmux plugins" "clone tpm + install plugins"
  fi
  if [ "${SHELL:-}" != "$(command -v zsh 2>/dev/null)" ]; then
    plan "default shell" "chsh to zsh"
  else
    plan "default shell" "already zsh"
  fi
}

detect_platform() {
  case "$(uname -m)" in
    x86_64|amd64) ARCH=amd64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *) ARCH="$(uname -m)" ;;
  esac
  case "$ARCH" in
    amd64) RUST_ARCH=x86_64 ;;
    arm64) RUST_ARCH=aarch64 ;;
    *) RUST_ARCH="$ARCH" ;;
  esac
  if [ "$OS" = macos ]; then
    RUST_PLATFORM="apple-darwin"
    GO_PLATFORM="darwin"
    FONT_DIR="$HOME/Library/Fonts"
  else
    RUST_PLATFORM="unknown-linux-gnu"
    GO_PLATFORM="linux"
    FONT_DIR="$HOME/.local/share/fonts"
  fi
}

github_latest_asset() {
  local repo="$1" pattern="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | sed -E 's/.*"(https[^"]+)"/\1/' \
    | grep -E "$pattern" \
    | head -n1
}

install_release_binary() {
  local repo="$1" pattern="$2" binname="$3"
  local url
  url="$(github_latest_asset "$repo" "$pattern")"
  if [ -z "$url" ]; then
    warn "Could not find a release asset for $repo matching '$pattern'"
    return 1
  fi
  log "Installing $binname from $url"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$url" | tar -xz -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  find "$tmp" -type f -name "$binname" -exec install -m755 {} "$HOME/.local/bin/$binname" \;
  rm -rf "$tmp"
  have "$binname" || { warn "$binname was not installed correctly"; return 1; }
}

install_base_packages() {
  confirm "Install base packages (git zsh tmux stow figlet ...)?" || {
    warn "Skipping base packages; stow is required later to link the dotfiles"
    return 0
  }
  case "$OS" in
    macos)
      if ! have brew; then
        log "Installing Homebrew"
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
      fi
      log "Installing base packages via Homebrew"
      brew update
      brew install git zsh tmux stow figlet
      ;;
    arch)
      log "Installing base packages via pacman"
      sudo pacman -Syu --needed --noconfirm git zsh tmux stow figlet curl unzip
      ;;
    fedora)
      log "Installing base packages via dnf"
      sudo dnf install -y git zsh tmux stow figlet curl unzip tar
      ;;
    debian)
      log "Installing base packages via apt"
      sudo apt-get update
      sudo apt-get install -y git zsh tmux stow figlet curl unzip tar
      ;;
  esac
}

# Debian/Ubuntu repos lag far behind upstream for these tools, so fetch
# upstream releases there. Elsewhere native packages stay current through
# normal system upgrades, which matters because this script never revisits
# a tool once it is installed.

pm_tracks_upstream() {
  case "$OS" in
    arch|macos|fedora) return 0 ;;
    *) return 1 ;;
  esac
}

install_native() {
  local pkg="$1"
  case "$OS" in
    macos) brew install "$pkg" ;;
    arch) sudo pacman -S --needed --noconfirm "$pkg" ;;
    fedora) sudo dnf install -y "$pkg" ;;
  esac
}

install_neovim() {
  have nvim && { log "neovim already installed"; return 0; }
  confirm "Install neovim?" || { skip neovim; return 0; }
  if pm_tracks_upstream; then
    install_native neovim
    return
  fi
  local pattern
  case "$ARCH" in
    amd64) pattern='nvim-linux(-x86_64|64)\.tar\.gz$' ;;
    arm64) pattern='nvim-linux-arm64\.tar\.gz$' ;;
    *) warn "No known neovim release asset for arch $ARCH"; return 1 ;;
  esac
  local url
  url="$(github_latest_asset neovim/neovim "$pattern")"
  if [ -z "$url" ]; then
    warn "Could not find a neovim release asset for $ARCH"
    return 1
  fi
  log "Installing neovim from $url"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$url" | tar -xz -C "$tmp" --strip-components=1 || { rm -rf "$tmp"; return 1; }
  sudo rm -rf /opt/nvim
  sudo mv "$tmp" /opt/nvim
  mkdir -p "$HOME/.local/bin"
  ln -sf /opt/nvim/bin/nvim "$HOME/.local/bin/nvim"
}

install_fzf() {
  have fzf && { log "fzf already installed"; return 0; }
  confirm "Install fzf?" || { skip fzf; return 0; }
  if pm_tracks_upstream; then
    install_native fzf
    return
  fi
  install_release_binary junegunn/fzf "fzf-[0-9.]+-${GO_PLATFORM}_${ARCH}\.tar\.gz\$" fzf
}

install_ripgrep() {
  have rg && { log "ripgrep already installed"; return 0; }
  confirm "Install ripgrep?" || { skip ripgrep; return 0; }
  if pm_tracks_upstream; then
    install_native ripgrep
    return
  fi
  # ripgrep doesn't publish a linux-gnu asset for every arch (e.g. x86_64 is
  # musl-only), so accept either libc flavor.
  install_release_binary BurntSushi/ripgrep "ripgrep-[0-9.]+-${RUST_ARCH}-unknown-linux-(gnu|musl)\.tar\.gz\$" rg
}

install_fd() {
  have fd && { log "fd already installed"; return 0; }
  confirm "Install fd?" || { skip fd; return 0; }
  if pm_tracks_upstream; then
    if [ "$OS" = fedora ]; then
      install_native fd-find
    else
      install_native fd
    fi
    return
  fi
  install_release_binary sharkdp/fd "fd-v[0-9.]+-${RUST_ARCH}-${RUST_PLATFORM}\.tar\.gz\$" fd
}

install_bat() {
  have bat && { log "bat already installed"; return 0; }
  confirm "Install bat?" || { skip bat; return 0; }
  if pm_tracks_upstream; then
    install_native bat
    return
  fi
  install_release_binary sharkdp/bat "bat-v[0-9.]+-${RUST_ARCH}-${RUST_PLATFORM}\.tar\.gz\$" bat
}

install_starship() {
  have starship && { log "starship already installed"; return 0; }
  confirm "Install starship?" || { skip starship; return 0; }
  case "$OS" in
    arch|macos) install_native starship; return ;;
  esac
  # No official Fedora package, and Debian/Ubuntu lag badly.
  log "Installing starship via official install script"
  # The installer refuses a --bin-dir that doesn't exist yet.
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
}

install_zoxide() {
  have zoxide && { log "zoxide already installed"; return 0; }
  confirm "Install zoxide?" || { skip zoxide; return 0; }
  if pm_tracks_upstream; then
    install_native zoxide
    return
  fi
  log "Installing zoxide via official install script"
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
}

install_opencode() {
  have opencode && { log "opencode already installed"; return 0; }
  confirm "Install opencode (via opencode.ai install script)?" || { skip opencode; return 0; }
  log "Installing opencode"
  # Without --no-modify-path the installer appends to ~/.zshrc, which is either
  # the stock file stow is about to back up or the tracked one in this repo.
  curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path || return
  local path_line='export PATH="$HOME/.opencode/bin:$PATH"'
  grep -qxF "$path_line" "$HOME/.zshrc.local" 2>/dev/null \
    || printf '%s\n' "$path_line" >> "$HOME/.zshrc.local"
}

font_installed() {
  if [ "$OS" = arch ]; then
    pacman -Q ttf-jetbrains-mono-nerd >/dev/null 2>&1
  else
    compgen -G "$FONT_DIR/JetBrainsMonoNerdFont*.ttf" >/dev/null 2>&1
  fi
}

install_fonts() {
  if font_installed; then
    log "JetBrains Mono Nerd Font already installed"
    return 0
  fi
  confirm "Install JetBrains Mono Nerd Font?" || { skip fonts; return 0; }
  if [ "$OS" = arch ]; then
    log "Installing JetBrains Mono Nerd Font via pacman"
    install_native ttf-jetbrains-mono-nerd
    return
  fi

  log "Installing JetBrains Mono Nerd Font"
  mkdir -p "$FONT_DIR"
  local tmp
  tmp="$(mktemp -d)"
  curl -fLo "$tmp/JetBrainsMono.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip \
    && unzip -oq "$tmp/JetBrainsMono.zip" -d "$FONT_DIR" \
    || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  if [ "$OS" != macos ]; then
    fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
  fi
}

install_paru() {
  have paru && return 0
  confirm "Install paru (AUR helper, built with makepkg)?" || { skip paru; return 0; }
  log "Installing paru (AUR helper)"
  sudo pacman -S --needed --noconfirm base-devel
  local tmp
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$tmp"
  (cd "$tmp" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

install_optional_apps() {
  $OPTIONAL || return 0
  log "Installing optional apps"
  case "$OS" in
    macos)
      confirm "Install Ghostty?" && brew install --cask ghostty
      ;;
    arch)
      confirm "Install Ghostty?" && sudo pacman -S --needed --noconfirm ghostty
      run_step "paru" install_paru
      ;;
    fedora)
      warn "Ghostty has no official Fedora package; see https://ghostty.org for manual install"
      ;;
    debian)
      warn "Ghostty has no official Debian/Ubuntu package; see https://ghostty.org for manual install"
      ;;
  esac
  install_opencode
}

setup_tpm() {
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"
  if [ -d "$tpm_dir" ]; then
    log "tpm already present"
    return 0
  fi
  log "Cloning tpm"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
}

stow_dotfiles() {
  log "Stowing dotfiles"
  local out
  out="$(cd "$DOTFILES_DIR" && stow --no-folding --target="$HOME" . 2>&1)" && return 0

  # Stow refuses to touch existing files it doesn't own. Move the conflicting
  # files into a timestamped backup dir and retry once.
  local conflicts
  conflicts="$(printf '%s\n' "$out" \
    | sed -nE -e 's/.*existing target is neither a symlink nor a directory: (.*)/\1/p' \
              -e 's/.*over existing target ([^ ]+) since.*/\1/p' \
    | sort -u)"
  if [ -z "$conflicts" ]; then
    warn "stow failed:"
    printf '%s\n' "$out" >&2
    return 1
  fi

  local backup_dir
  backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
  warn "Existing files conflict with the dotfiles; backing them up to $backup_dir"
  local f
  while IFS= read -r f; do
    [ -e "$HOME/$f" ] || [ -L "$HOME/$f" ] || continue
    mkdir -p "$backup_dir/$(dirname "$f")"
    mv "$HOME/$f" "$backup_dir/$f"
    log "  moved $f"
  done <<<"$conflicts"

  (cd "$DOTFILES_DIR" && stow --no-folding --target="$HOME" .)
}

install_tmux_plugins() {
  local installer="$HOME/.config/tmux/plugins/tpm/bin/install_plugins"
  if [ -x "$installer" ]; then
    log "Installing tmux plugins"
    "$installer"
  else
    warn "tpm installer not found at $installer; run 'prefix + I' inside tmux to install plugins"
  fi
}

main() {
  detect_os
  detect_platform

  if $DRY_RUN; then
    dry_run_plan
    return 0
  fi

  run_step "base packages" install_base_packages
  run_step "neovim" install_neovim
  run_step "fzf" install_fzf
  run_step "ripgrep" install_ripgrep
  run_step "fd" install_fd
  run_step "bat" install_bat
  run_step "starship" install_starship
  run_step "zoxide" install_zoxide
  run_step "fonts" install_fonts
  run_step "optional apps" install_optional_apps

  run_step "dotfiles (stow)" stow_dotfiles
  if confirm "Set up tmux plugins (clone tpm and install plugins)?"; then
    run_step "tpm" setup_tpm
    run_step "tmux plugins" install_tmux_plugins
  else
    skip "tmux plugins"
  fi

  log "Done. Restart your shell (or run 'exec zsh') to pick up the new config."

  local zsh_path
  zsh_path="$(command -v zsh)"
  if [ "${SHELL:-}" != "$zsh_path" ]; then
    confirm "Set zsh as your default shell?" || return 0
    if chsh -s "$zsh_path"; then
      log "Set zsh as your default shell. Log out and back in for it to take effect."
    else
      warn "Could not set zsh as your default shell automatically."
      warn "On macOS this usually means $zsh_path isn't listed in /etc/shells yet:"
      warn "  echo \"$zsh_path\" | sudo tee -a /etc/shells"
      log "Then run: chsh -s $zsh_path"
    fi
  fi
}

main

if [ "${#FAILED[@]}" -gt 0 ]; then
  warn "These steps failed:"
  printf '  %s\n' "${FAILED[@]}" >&2
  exit 1
fi
