ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"


if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

bindkey -e

zinit ice depth=1; zinit light romkatv/powerlevel10k

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

autoload -Uz compinit && compinit
_comp_options+=(globdots)

zinit cdreplay -q
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

HISTSIZE=2000
HISTFILE=~/.cache/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

alias ls='ls --color'
alias grep='grep --color'

if [ -n "${commands[fzf]}" ]; then
eval "$(fzf --zsh)"
fi

eval "$(zoxide init --cmd cd zsh)"

bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey '^H' backward-kill-word
bindkey '5~' kill-word
bindkey "^[[3~" delete-char
bindkey -s ^f "tmux-sessionizer\n"
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
export PATH=$PATH:~/.local/bin/
export PATH=$PATH:~/go/bin/


figlet K TushaR N -c -k

[[ ! -f ~/.cache/.p10k.zsh ]] || source ~/.cache/.p10k.zsh
