ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"


if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

bindkey -e

zinit ice wait lucid
zinit light zsh-users/zsh-completions

zinit ice wait lucid atload'_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

zinit ice wait lucid
zinit light Aloxaf/fzf-tab

zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
(( $+commands[aws] )) && zinit snippet OMZP::aws
(( $+commands[kubectl] )) && zinit snippet OMZP::kubectl
(( $+commands[kubectx] )) && zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

autoload -Uz compinit
if [[ -n ~/.cache/.zcompdump(#qN.mh+24) ]]; then
  compinit -d ~/.cache/.zcompdump
else
  compinit -C -d ~/.cache/.zcompdump
fi
_comp_options+=(globdots)

zinit cdreplay -q
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

HISTSIZE=100000
HISTFILE=~/.cache/.zsh_history
SAVEHIST=$HISTSIZE
setopt appendhistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups
# setopt sharehistory  # Share history between terminal sessions (disabled intentionally)
setopt correct

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

alias ls='ls --color'
alias grep='grep --color'

if (( $+commands[fzf] )); then
  eval "$(fzf --zsh)"

  if (( $+commands[fd] )); then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi

  # Catppuccin Mocha
  export FZF_DEFAULT_OPTS="\
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--height 60% --layout=reverse --border"

  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || ls --color {}'"
  export FZF_ALT_C_OPTS="--preview 'ls --color {}'"
fi

(( $+commands[zoxide] )) && eval "$(zoxide init --cmd cd zsh)"

bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word  # Ctrl+Delete
bindkey "^[[3~" delete-char

# Stash any half-typed command (restored at next prompt), then run the
# sessionizer as a real foreground command so `tmux attach` gets the terminal.
# Leading space keeps it out of history via hist_ignore_space.
_tmux-sessionizer-widget() {
  [[ -n $BUFFER ]] && zle push-input
  BUFFER=" tmux-sessionizer"
  zle accept-line
}
zle -N _tmux-sessionizer-widget
bindkey '^f' _tmux-sessionizer-widget
alias tmux-root='tmux new -A -s root'

#Always open in tmux
# tmux_root_name="root"
# if [[ -z $TMUX ]]; then
#    if ! tmux has-session -t=$tmux_root_name 2> /dev/null; then
#        tmux new-session -s $tmux_root_name
#    else
#        tmux switch-client -t $tmux_root_name
#    fi
# fi

export EDITOR=nvim
typeset -U path
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/go/bin:$PATH"

# Machine-specific config (untracked)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

[[ -o interactive ]] && (( $+commands[figlet] )) && figlet K TushaR N -c -k

eval "$(starship init zsh)"

