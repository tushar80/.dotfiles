# Dotfiles

My personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and Git.

## Required Software

- [GNU Stow](https://www.gnu.org/software/stow/)
- Git
- Zsh
- Neovim
- tmux
- Starship
- fzf
- zoxide
- ripgrep
- fd

### System Packages

Install these packages from system's package repository:

**Debian/Ubuntu:**

```bash
sudo apt install git zsh neovim tmux ripgrep stow fd-find fzf zoxide
```

**Arch Linux:**

```bash
sudo pacman -S git zsh neovim tmux ripgrep stow fd fzf zoxide starship
```

Optional Arch/AUR tooling:

```bash
paru -S opencode-bin ghostty
```

### Manual Installation: Starship

If Starship is not available from your system package manager:

```bash
curl -sS https://starship.rs/install.sh | sh
```

### Manual Installation: fzf

Since fzf may not be up-to-date in Debian/Ubuntu repositories, install the latest version from GitHub:

```bash
# Download and install fzf to ~/.local/bin
curl -L https://github.com/junegunn/fzf/releases/download/v0.65.1/fzf-0.65.1-linux_amd64.tar.gz | tar -xz -C ~/.local/bin
```

### Fonts

Install **JetBrains Mono Nerd Font**.

```bash
cd ~/.local/share/fonts

curl -fLo "JetBrainsMono.zip" \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip

unzip -o JetBrainsMono.zip
rm JetBrainsMono.zip

fc-cache -fv
```

## Clone

Clone with submodules so tmux plugin manager is available immediately:

```bash
git clone --recurse-submodules <repo-url> ~/.dotfiles
```

If the repo is already cloned:

```bash
git submodule update --init --recursive
```

## Deploy Dotfiles Using Stow

```bash
# Deploy all dotfiles
stow --no-folding .

# Or deploy specific configurations
stow --no-folding --target=~ .config
```

## Notes

- Always use `--no-folding` flag when stowing to maintain proper directory structure
- `tmux-sessionizer` searches `$HOME/Projects` and `$HOME/HomeWork` by default. Override with colon-separated `TMUX_SESSIONIZER_DIRS`, for example `TMUX_SESSIONIZER_DIRS="$HOME/Code:$HOME/Work"`.
