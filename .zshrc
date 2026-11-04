# zsh config (ported from .bashrc in github.com/RyanAHayden/dotfiles)
PROMPT='%B%F{7}%1~%f%b %B%F{15}❯%f%b '

bindkey -v
KEYTIMEOUT=1

# completion, case-insensitive; compinit runs on the first Tab so startup stays fast
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}'
_complete_word() {
	(( $+functions[compdef] )) || { autoload -Uz compinit; compinit -C -d "$HOME/.cache/zcompdump-$ZSH_VERSION"; }
	zle complete-word
}
zle -N _complete_word
bindkey '^I' _complete_word

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt AUTO_CD HIST_IGNORE_DUPS HIST_IGNORE_SPACE INTERACTIVE_COMMENTS SHARE_HISTORY

export EDITOR=nvim
export MANPAGER='nvim +Man!'
typeset -gU path
path=("$HOME/.local/bin" "$HOME/bin" $path)

alias n=nvim
command -v eza >/dev/null && alias ls='eza --icons'
# c = claude (cld wrapper if installed)
command -v cld >/dev/null && alias c=cld || alias c=claude

# t [session] = attach (to named session if given), else new "Work"
t() { tmux attach ${1:+-t "$1"} || tmux new -s "${1:-Work}"; }
# stay cmd... = run detached from the terminal
stay() { nohup "$@" >/dev/null 2>&1 </dev/null & disown; }
