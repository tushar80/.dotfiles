# Dotfiles

Personal dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/) and Git.

## Clone

```bash
git clone git@github.com:tushar80/.dotfiles.git ~/.dotfiles
```

## Automated Setup

`setup.sh` installs the required software, stows the dotfiles, and sets up
tmux plugins on Debian/Ubuntu, Arch Linux, Fedora, or macOS.

```bash
cd ~/.dotfiles
./setup.sh              # required software only
./setup.sh --optional   # also installs Ghostty, paru, opencode
./setup.sh --dry-run    # show what would be installed, without installing
```

It confirms the detected OS and package manager, then asks `[Y/n]` (default
yes) before each install, the tmux plugin setup, and the default shell
change. Installed tools are skipped without a prompt, so re-running is safe.
Without a terminal, every prompt is accepted.

A failed step doesn't stop the script. Failures are listed at the end and the
script exits 1.

Existing files that block stow are moved to `~/.dotfiles-backup/<timestamp>/`
and stow is retried.

opencode's PATH line goes in `~/.zshrc.local`, not the stowed `~/.zshrc`.

### Where packages come from

`git`, `zsh`, `tmux`, `stow`, and `figlet` always come from the native package
manager. For `neovim`, `fzf`, `ripgrep`, `fd`, `bat`, `starship`, and `zoxide`:

- **Arch, Fedora, macOS**: native packages, so normal system upgrades keep
  them current. The script never updates a tool after installing it.
- **Debian/Ubuntu**: the latest GitHub release, or the official install
  script for starship and zoxide. apt lags well behind upstream for these.

Fedora packages `fd` as `fd-find` (the binary is still `fd`) and has no
official starship package, so starship uses its install script there.

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
- [zinit](https://github.com/zdharma-continuum/zinit) (installed by `.zshrc` on first launch)
- bat (optional, fzf previews)
- figlet (optional, shell banner)

Optional apps with configs in this repo:

- [Ghostty](https://ghostty.org/) (terminal)
- [paru](https://github.com/Morganamilo/paru) (AUR helper)
- [opencode](https://opencode.ai/) (AI coding agent)

## Manual Installation

Only needed if you skip `setup.sh`.

**Arch Linux:**

```bash
sudo pacman -S git zsh neovim tmux ripgrep stow fd fzf zoxide starship bat figlet
```

**Fedora** (plus starship, below):

```bash
sudo dnf install git zsh neovim tmux ripgrep stow fd-find fzf zoxide bat figlet
```

**macOS (Homebrew):**

```bash
brew install git zsh neovim tmux ripgrep fd fzf zoxide starship bat figlet stow
```

**Debian/Ubuntu:**

```bash
sudo apt install git zsh tmux stow figlet
```

Then install fzf, ripgrep, fd, and bat from their GitHub releases. For fzf on
Linux amd64:

```bash
url=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest \
  | grep -oE '"browser_download_url": *"[^"]*linux_amd64\.tar\.gz"' \
  | sed -E 's/.*"(https[^"]+)"/\1/')
curl -L "$url" | tar -xz -C ~/.local/bin
```

The others work the same way with `BurntSushi/ripgrep`, `sharkdp/fd`, and
`sharkdp/bat`. Neovim's release unpacks into `/opt/nvim`. `setup.sh` has the
exact asset patterns per OS and arch.

### starship, zoxide, opencode

```bash
curl -fsSL https://starship.rs/install.sh | sh    # Fedora, Debian/Ubuntu
curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash    # Debian/Ubuntu
curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
echo 'export PATH="$HOME/.opencode/bin:$PATH"' >> ~/.zshrc.local
```

`--no-modify-path` stops the opencode installer from appending to the stowed
`~/.zshrc`.

### Fonts

Install **JetBrains Mono Nerd Font**. On Arch:

```bash
sudo pacman -S ttf-jetbrains-mono-nerd
```

Elsewhere:

```bash
cd ~/.local/share/fonts   # macOS: ~/Library/Fonts

curl -fLo "JetBrainsMono.zip" \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip

unzip -o JetBrainsMono.zip
rm JetBrainsMono.zip

fc-cache -fv   # Linux only
```

### Stow

```bash
cd ~/.dotfiles
stow --no-folding --target="$HOME" .
```

Always pass `--no-folding`. Without it, stow links whole directories such as
`~/.config/nvim`, so files apps write there end up in the repo.

### tmux plugins

```bash
git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
~/.config/tmux/plugins/tpm/bin/install_plugins
# or from inside tmux: prefix + I
```

## Notes

- tmux prefix is `C-a`.
- `tmux-sessionizer` searches `$HOME/Projects` and `$HOME/HomeWork`. Override with colon-separated `TMUX_SESSIONIZER_DIRS`, e.g. `TMUX_SESSIONIZER_DIRS="$HOME/Code:$HOME/Work"`. Bound to `C-f` in tmux and `Ctrl-f` in zsh.
- `Alt+\` in tmux toggles a floating scratch terminal.
- `~/.zshrc.local` is untracked and sourced near the end of `.zshrc`, before the figlet banner and starship init. Put secrets and machine-specific config there.
- Theme is Catppuccin Mocha across fzf, tmux, and Ghostty.
