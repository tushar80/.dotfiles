# 🏠 Dotfiles

My personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and Git.

## Required Software

- [GNU Stow](https://www.gnu.org/software/stow/)
- Git

### System Packages

Install these packages from system's package repository:

**Debian/Ubuntu:**

```bash
sudo apt install tmux ripgrep stow fd-find
```

**Arch Linux:**

```bash
sudo pacman -S tmux ripgrep stow fd fzf
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

## Deploy dotfiles using Stow

   ```bash
   # Deploy all dotfiles
   stow --no-folding .
   
   # Or deploy specific configurations
   stow --no-folding --target=~ .config
   ```

## ⚠️ Notes

- Always use `--no-folding` flag when stowing to maintain proper directory structure
