#!/usr/bin/env bash
# Bootstraps this dotfiles repo on a fresh machine: installs required (and
# optionally optional) software, stows configs, and wires up tmux plugins.
# Supports Debian/Ubuntu, Arch Linux, Fedora, and macOS.
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPTIONAL=false
DRY_RUN=false

# Several tools install into ~/.local/bin (release binaries, starship/zoxide
# install scripts). On a fresh machine it isn't on PATH yet, which would make
# the post-install `have` checks falsely report failure.
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

  --optional   also install optional apps (Alacritty, Ghostty, Zed, paru, opencode)
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
  # Prompt [Y/n]; default yes. Reads from the terminal directly so it still
  # works when the script itself is piped into bash. Auto-accepts when no
  # terminal is available (unattended runs).
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

skip() { log "Skipping $1"; return 0; }

run_step() {
  local desc="$1"; shift
  if "$@"; then
    return 0
  else
    warn "Step failed: $desc (continuing)"
    return 0
  fi
}

OS=""
ARCH=""
RUST_ARCH=""
RUST_PLATFORM=""
GO_PLATFORM=""

detect_os() {
  case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case " ${ID:-} ${ID_LIKE:-} " in
          *arch*|*manjaro*) OS=arch ;;
          *fedora*|*rhel*) OS=fedora ;;
          *debian*|*ubuntu*) OS=debian ;;
          *) OS=unknown ;;
        esac
      else
        OS=unknown
      fi
      ;;
    *) OS=unknown ;;
  esac

  if [ "$OS" = unknown ]; then
    warn "Unsupported or undetected OS. See README.md for manual installation."
    exit 1
  fi

  local pm
  case "$OS" in
    macos) pm="Homebrew (brew)" ;;
    arch) pm=pacman ;;
    fedora) pm=dnf ;;
    debian) pm="apt-get" ;;
  esac
  if $DRY_RUN; then
    log "Detected OS: $OS (package manager: $pm)"
    return 0
  fi
  if ! confirm "Detected OS: $OS — use $pm as the package manager?"; then
    warn "Aborted. Nothing was installed."
    exit 1
  fi
}

# --- Dry run -------------------------------------------------------------------

plan() { printf '  %-24s %s\n' "$1" "$2"; }

plan_tool() {
  # $1 = binary to check, $2 = display name, $3 = install method if missing
  if have "$1"; then
    plan "$2" "already installed"
  else
    plan "$2" "$3"
  fi
}

dry_run_plan() {
  local pm native
  case "$OS" in
    macos) pm=brew ;;
    arch) pm=pacman ;;
    fedora) pm=dnf ;;
    debian) pm=apt-get ;;
  esac
  native="native package ($pm)"

  log "Dry run — nothing will be installed. Plan for this machine:"
  plan "base packages" "git zsh tmux stow figlet ... via $pm"
  if pm_tracks_upstream; then
    plan_tool nvim neovim "$native"
    plan_tool fzf fzf "$native"
    plan_tool rg ripgrep "$native"
    if [ "$OS" = fedora ]; then
      plan_tool fd fd "$native (fd-find, aliased to fd)"
    else
      plan_tool fd fd "$native"
    fi
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

  local font_installed=false font_dir
  if [ "$OS" = arch ]; then
    pacman -Q ttf-jetbrains-mono-nerd >/dev/null 2>&1 && font_installed=true
    font_dir="native package ($pm: ttf-jetbrains-mono-nerd)"
  else
    [ "$OS" = macos ] && font_dir="$HOME/Library/Fonts" || font_dir="$HOME/.local/share/fonts"
    compgen -G "$font_dir/JetBrainsMonoNerdFont*.ttf" >/dev/null 2>&1 && font_installed=true
    font_dir="GitHub release zip -> $font_dir"
  fi
  if $font_installed; then
    plan "JetBrains Mono NF" "already installed"
  else
    plan "JetBrains Mono NF" "$font_dir"
  fi

  if $OPTIONAL; then
    case "$OS" in
      macos)
        plan_tool alacritty Alacritty "brew cask"
        plan Ghostty "brew cask"
        plan Zed "brew cask"
        ;;
      arch)
        plan_tool alacritty Alacritty "$native"
        plan_tool ghostty Ghostty "$native"
        plan_tool paru paru "AUR (makepkg)"
        plan_tool zed Zed "zed.dev install script"
        ;;
      *)
        plan_tool alacritty Alacritty "$native (may be unavailable)"
        plan Ghostty "no official package — manual install"
        plan_tool zed Zed "zed.dev install script"
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
  else
    RUST_PLATFORM="unknown-linux-gnu"
    GO_PLATFORM="linux"
  fi
}

# --- Latest-release helpers (used for tools that lag in distro repos) ------

github_latest_asset() {
  # $1 = owner/repo, $2 = extended-regex pattern matching the asset filename
  local repo="$1" pattern="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | sed -E 's/.*"(https[^"]+)"/\1/' \
    | grep -E "$pattern" \
    | head -n1
}

install_release_binary() {
  # Downloads a .tar.gz release asset and installs a single binary from it
  # into ~/.local/bin.
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

# --- Base packages (native package manager per OS) --------------------------

install_base_packages() {
  confirm "Install base packages (git zsh tmux stow figlet ...)?" || {
    warn "Skipping base packages — stow is required later to link the dotfiles"
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
      sudo pacman -Sy --needed --noconfirm git zsh tmux stow figlet curl unzip
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

# --- Native package manager everywhere except Debian/Ubuntu, whose repos
# measurably lag upstream for these fast-moving tools (checked against live
# repo/mdapi data while writing this script). Arch, Fedora, and macOS all
# either match upstream releases closely or update on a cadence that's fine
# to ride — and, unlike a one-off binary dropped in ~/.local/bin, they stay
# current through the normal `pacman -Syu` / `dnf upgrade` / `brew upgrade`
# you're already running, since this script never re-checks a tool once
# `have` finds it installed.

pm_tracks_upstream() {
  case "$OS" in
    arch|macos|fedora) return 0 ;;
    *) return 1 ;;
  esac
}

install_native() {
  # $1 = package name (same across pacman/dnf/brew for most of these tools)
  local pkg="$1"
  case "$OS" in
    macos) brew install "$pkg" ;;
    arch) sudo pacman -S --needed --noconfirm "$pkg" ;;
    fedora) sudo dnf install -y "$pkg" ;;
  esac
}

# Some distros package a tool under a different name and/or binary than
# upstream (e.g. Fedora's fd is packaged as fd-find). Symlink the renamed
# binary to the expected name if needed.
ensure_binary_alias() {
  local expected="$1" alternative="$2"
  have "$expected" && return 0
  if have "$alternative"; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v "$alternative")" "$HOME/.local/bin/$expected"
  fi
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
  curl -fsSL "$url" | tar -xz -C "$tmp" --strip-components=1
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
      sudo dnf install -y fd-find
      ensure_binary_alias fd fdfind
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
  # Fedora has no official starship package (confirmed: 404/400 from
  # packages.fedoraproject.org and mdapi across branches); Debian/Ubuntu lag
  # badly too. Fall back to the official cross-platform install script.
  log "Installing starship via official install script"
  curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
}

install_zoxide() {
  have zoxide && { log "zoxide already installed"; return 0; }
  confirm "Install zoxide?" || { skip zoxide; return 0; }
  if pm_tracks_upstream; then
    install_native zoxide
    return
  fi
  log "Installing zoxide via official install script"
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
}

install_opencode() {
  have opencode && { log "opencode already installed"; return 0; }
  confirm "Install opencode (via opencode.ai install script)?" || { skip opencode; return 0; }
  log "Installing opencode"
  curl -fsSL https://opencode.ai/install | bash
}

# --- Fonts -------------------------------------------------------------------

install_fonts() {
  if [ "$OS" = arch ]; then
    if pacman -Q ttf-jetbrains-mono-nerd >/dev/null 2>&1; then
      log "JetBrains Mono Nerd Font already installed"
      return 0
    fi
    confirm "Install JetBrains Mono Nerd Font?" || { skip fonts; return 0; }
    log "Installing JetBrains Mono Nerd Font via pacman"
    install_native ttf-jetbrains-mono-nerd
    return
  fi

  local font_dir
  if [ "$OS" = macos ]; then
    font_dir="$HOME/Library/Fonts"
  else
    font_dir="$HOME/.local/share/fonts"
  fi

  if compgen -G "$font_dir/JetBrainsMonoNerdFont*.ttf" >/dev/null 2>&1; then
    log "JetBrains Mono Nerd Font already installed"
    return 0
  fi

  confirm "Install JetBrains Mono Nerd Font?" || { skip fonts; return 0; }
  log "Installing JetBrains Mono Nerd Font"
  mkdir -p "$font_dir"
  local tmp
  tmp="$(mktemp -d)"
  curl -fLo "$tmp/JetBrainsMono.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -oq "$tmp/JetBrainsMono.zip" -d "$font_dir"
  rm -rf "$tmp"
  if [ "$OS" != macos ]; then
    fc-cache -f "$font_dir" >/dev/null 2>&1 || true
  fi
}

# --- Optional apps ------------------------------------------------------------

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
      confirm "Install Alacritty?" && brew install --cask alacritty
      confirm "Install Ghostty?" && brew install --cask ghostty
      confirm "Install Zed?" && brew install --cask zed
      ;;
    arch)
      confirm "Install Alacritty?" && sudo pacman -S --needed --noconfirm alacritty
      confirm "Install Ghostty?" && sudo pacman -S --needed --noconfirm ghostty
      run_step "paru" install_paru
      confirm "Install Zed (via zed.dev install script)?" && curl -fsSL https://zed.dev/install.sh | sh
      ;;
    fedora)
      if confirm "Install Alacritty?"; then
        sudo dnf install -y alacritty || warn "alacritty unavailable via dnf; install manually"
      fi
      warn "Ghostty has no official Fedora package; see https://ghostty.org for manual install"
      confirm "Install Zed (via zed.dev install script)?" && curl -fsSL https://zed.dev/install.sh | sh
      ;;
    debian)
      if confirm "Install Alacritty?"; then
        sudo apt-get install -y alacritty || warn "alacritty unavailable via apt; install manually"
      fi
      warn "Ghostty has no official Debian/Ubuntu package; see https://ghostty.org for manual install"
      confirm "Install Zed (via zed.dev install script)?" && curl -fsSL https://zed.dev/install.sh | sh
      ;;
  esac
  install_opencode
}

# --- Dotfiles: stow + tmux plugins -------------------------------------------

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

  stow_dotfiles
  if confirm "Set up tmux plugins (clone tpm and install plugins)?"; then
    setup_tpm
    install_tmux_plugins
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
