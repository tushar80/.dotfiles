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
- [zinit](https://github.com/zdharma-continuum/zinit) (auto-installed by `.zshrc` on first launch)
- bat (optional, used for fzf previews)
- figlet (optional, shell banner)

Optional apps with configs included in this repo:

- [Alacritty](https://alacritty.org/) (terminal)
- [Ghostty](https://ghostty.org/) (terminal)
- [Zed](https://zed.dev/) (editor)
- [paru](https://github.com/Morganamilo/paru) (AUR helper)
- [opencode](https://opencode.ai/) (AI coding agent)

### System Packages

`./setup.sh` (see [Automated Setup](#automated-setup) below) installs all of
this on Debian/Ubuntu, Arch Linux, Fedora, and macOS. The manual
steps below are only needed if you'd rather install things yourself.

**Debian/Ubuntu:**

```bash
sudo apt install git zsh tmux ripgrep stow figlet
# neovim, fzf, bat, and fd from apt lag upstream releases significantly;
# install those from their GitHub releases instead (setup.sh does this).
```

**Arch Linux:**

```bash
sudo pacman -S git zsh neovim tmux ripgrep stow fd fzf zoxide starship bat figlet
```

**Fedora:**

```bash
sudo dnf install git zsh neovim tmux ripgrep stow fd-find fzf zoxide bat figlet
# starship has no official Fedora package; install it separately (see below)
```

**macOS (Homebrew):**

```bash
brew install git zsh neovim tmux ripgrep fd fzf zoxide starship bat figlet stow
```

### Manual Installation: Starship / zoxide / opencode

opencode has no distro packages at all, and starship has no official Fedora
package; both ship an official cross-platform install script that always
fetches the latest release. Debian/Ubuntu lack current packages for either,
so use the same scripts there too:

```bash
curl -sS https://starship.rs/install.sh | sh
curl -fsSL https://opencode.ai/install | bash
```

zoxide is a normal package everywhere except Debian/Ubuntu, where its own
install script works the same way:

```bash
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
```

### Manual Installation: fzf / ripgrep / fd / bat (Debian/Ubuntu only)

Arch, Fedora, and macOS package these close enough to upstream that
`setup.sh` just installs them natively (`fd` is packaged as `fd-find` on
Fedora — the binary itself is still called `fd`). Debian/Ubuntu's versions
lag enough that it's worth fetching the latest release from GitHub instead,
e.g. for fzf on Linux amd64:

```bash
url=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest \
  | grep -oE '"browser_download_url": *"[^"]*linux_amd64\.tar\.gz"' \
  | sed -E 's/.*"(https[^"]+)"/\1/')
curl -L "$url" | tar -xz -C ~/.local/bin
```

Swap the repo (`BurntSushi/ripgrep`, `sharkdp/fd`, `sharkdp/bat`) and asset
pattern for the others — see `setup.sh` for the exact patterns used per OS/arch.

### Fonts

Install **JetBrains Mono Nerd Font**. On Arch it's packaged natively:

```bash
sudo pacman -S ttf-jetbrains-mono-nerd
```

Elsewhere, grab it from the nerd-fonts releases:

```bash
cd ~/.local/share/fonts   # macOS: ~/Library/Fonts

curl -fLo "JetBrainsMono.zip" \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip

unzip -o JetBrainsMono.zip
rm JetBrainsMono.zip

fc-cache -fv   # Linux only
```

## Clone

```bash
git clone git@github.com:tushar80/.dotfiles.git ~/.dotfiles
```

## Automated Setup

`setup.sh` bootstraps a fresh machine end-to-end: installs required software
(always the latest upstream release, not whatever's stale in a distro's
repos), stows the dotfiles, clones tpm, and installs tmux plugins. It detects
Debian/Ubuntu, Arch Linux, Fedora, and macOS.

```bash
cd ~/.dotfiles
./setup.sh              # required software only
./setup.sh --optional   # also installs Alacritty, Ghostty, Zed, paru, opencode
./setup.sh --dry-run    # show what would be installed, without installing
```

The script is interactive: it confirms the detected OS/package manager up
front, then asks `[Y/n]` (default yes) before each tool it would install —
including the tmux plugin setup and changing your default shell. Tools that
are already installed don't prompt, so the script is safe to re-run. When run
non-interactively (no terminal), prompts auto-accept.

If stowing hits files that already exist (e.g. a stock `~/.zshrc` on a fresh
machine), they're moved to a timestamped `~/.dotfiles-backup/` directory and
stow is retried.

Notes on freshness: `git`/`zsh`/`tmux`/`stow`/`figlet` always come from the
native package manager. For `neovim`, `fzf`, `ripgrep`, `fd`, `bat`,
`starship`, and `zoxide`:

- **Arch, Fedora, and macOS**: native package manager (pacman/dnf/Homebrew) —
  preferred so these tools stay current through the normal `pacman -Syu` /
  `dnf upgrade` / `brew upgrade` you're already running, rather than as a
  one-off binary in `~/.local/bin` that this script never revisits once
  installed. Checked against live repo/mdapi data rather than assumed: Arch
  and macOS currently match upstream's latest release exactly; Fedora is a
  version or so behind for some of these (e.g. `ripgrep` 14.1.1 vs. upstream
  15.1.0 at the time of writing) but tracks its own release cadence closely
  enough that native packages are still the right call there. Two Fedora
  quirks: `fd` is packaged as `fd-find` (the binary is still `fd`), and
  `starship` has no official Fedora package at all, so it falls back to its
  install script there.
- **Debian/Ubuntu**: latest upstream GitHub release (or official install
  script for starship/zoxide) — its repos lag by a much wider margin (e.g.
  multi-year-old neovim on stable releases), so it's the one distro where
  fetching upstream directly is worth the trade-off.

## Deploy Dotfiles Using Stow

If you'd rather skip `setup.sh` and just deploy configs (e.g. software is
already installed):

```bash
# Deploy all dotfiles
stow --no-folding .

# Or deploy specific configurations
stow --no-folding --target=~ .config
```

### tmux plugins

`setup.sh` clones [tpm](https://github.com/tmux-plugins/tpm) and installs
the plugins declared in `.config/tmux/tmux.conf` (tmux-sensible,
catppuccin/tmux, tmux-yank) automatically. To do it manually:

```bash
git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
~/.config/tmux/plugins/tpm/bin/install_plugins
# or from inside tmux: prefix + I  (default prefix is C-a)
```

## Notes

- Always use `--no-folding` flag when stowing to maintain proper directory structure
- tmux prefix is `C-a` (not the default `C-b`)
- `tmux-sessionizer` searches `$HOME/Projects` and `$HOME/HomeWork` by default. Override with colon-separated `TMUX_SESSIONIZER_DIRS`, for example `TMUX_SESSIONIZER_DIRS="$HOME/Code:$HOME/Work"`. Bound to `C-f` inside tmux and `Ctrl-f` in zsh.
- `Alt+\` in tmux toggles a floating scratch terminal.
- Machine-specific overrides: `~/.zshrc.local` is sourced at the end of `.zshrc` if present, and is untracked so secrets and local aliases live there.
- Theme is Catppuccin Mocha across fzf, tmux, Alacritty, and Ghostty configs.
