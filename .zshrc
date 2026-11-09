# zsh config (ported from .bashrc in github.com/RyanAHayden/dotfiles and Omarchy's default/bash)

# emacs keys like bash/readline (Ctrl+A/E/W/U/K/R...)
bindkey -e
KEYTIMEOUT=1

# completion, case-insensitive; compinit runs on the first Tab so startup stays fast
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ''
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
_complete_word() {
	(( $+functions[compdef] )) || { autoload -Uz compinit; compinit -C -d "$HOME/.cache/zcompdump-$ZSH_VERSION"; }
	zle complete-word
}
zle -N _complete_word
bindkey '^I' _complete_word
bindkey '^[[Z' reverse-menu-complete

# Up/Down match what you've typed so far against history (ssh<Up> -> ssh rycs)
bindkey '^[[A' history-beginning-search-backward '^[OA' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward '^[OB' history-beginning-search-forward
# Ctrl+arrows word jump, Home/End, Delete
bindkey '^[[1;5C' forward-word '^[[1;5D' backward-word
bindkey '^[[H' beginning-of-line '^[OH' beginning-of-line '^[[1~' beginning-of-line
bindkey '^[[F' end-of-line '^[OF' end-of-line '^[[4~' end-of-line
bindkey '^[[3~' delete-char
# Ctrl+X Ctrl+E = edit the command line in nvim (like bash)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

HISTFILE="$HOME/.zsh_history"
HISTSIZE=32768
SAVEHIST=32768
setopt AUTO_CD HIST_IGNORE_DUPS HIST_IGNORE_SPACE INTERACTIVE_COMMENTS SHARE_HISTORY

export EDITOR=nvim
export SUDO_EDITOR=nvim
export MANPAGER='nvim +Man!'
export BAT_THEME=ansi
typeset -gU path
path=("$HOME/.local/bin" "$HOME/bin" $path)

# prompt: starship (same .config/starship.toml as Linux), plain fallback
PROMPT='%B%F{7}%1~%f%b %B%F{15}❯%f%b '
command -v starship >/dev/null && eval "$(starship init zsh)"

# fzf: Ctrl+R history, Ctrl+T files, Alt+C cd, **<Tab> completion
command -v fzf >/dev/null && source <(fzf --zsh)

# File system
if command -v eza >/dev/null; then
	alias ls='eza -lh --group-directories-first --icons=auto'
	alias lsa='ls -a'
	alias lt='eza --tree --level=2 --long --icons --git'
	alias lta='lt -a'
fi
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
alias eff='$EDITOR "$(ff)"'
# sff host:/dest = pick a file (newest first) and scp it there
sff() {
	[[ $# -eq 0 ]] && { echo "Usage: sff <destination> (e.g. sff host:/tmp/)"; return 1; }
	local file
	file=$(find . -type f -print0 | xargs -0 stat -f '%m%t%N' | sort -rn | cut -f2- | ff) && [[ -n $file ]] && scp "$file" "$1"
}

# cd falls back to zoxide (cd proj jumps to the most used dir matching "proj")
if command -v zoxide >/dev/null; then
	eval "$(zoxide init zsh)"
	alias cd=zd
	zd() {
		if (( $# == 0 )); then
			builtin cd ~ || return
		elif [[ -d $1 ]]; then
			builtin cd "$1" || return
		else
			z "$@" || { echo "Error: Directory not found"; return 1; }
			printf "\U000F17A9 "
			pwd
		fi
	}
fi

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
n() { if (( $# == 0 )); then command nvim .; else command nvim "$@"; fi }
alias d=docker
# c = claude (cld wrapper if installed)
command -v cld >/dev/null && alias c=cld || alias c=claude
# t [session] = attach (to named session if given), else new "Work"
t() { tmux attach ${1:+-t} $1 || tmux new -s "${1:-Work}"; }
# stay cmd... = run detached from the terminal
stay() { nohup "$@" >/dev/null 2>&1 </dev/null & disown; }

# Git
alias g=git
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'
# ga branch = new branch in worktree ../<repo>--<branch>; gd (inside it) = remove worktree and branch
ga() {
	[[ -z $1 ]] && { echo "Usage: ga [branch name]"; return 1; }
	local wt_path="../${PWD:t}--$1"
	git worktree add -b "$1" "$wt_path" && builtin cd "$wt_path"
}
gd() {
	read -q "?Remove worktree and branch? [y/N] " || { echo; return; }
	echo
	local cwd=$PWD worktree=${PWD:t}
	local root=${worktree%%--*} branch=${worktree#*--}
	# Protect against accidentally nuking a non-worktree directory
	if [[ $root != "$worktree" ]]; then
		builtin cd "../$root" && git worktree remove "$cwd" --force && git branch -D "$branch"
	fi
}

# Compression
compress() { tar -czf "${1%/}.tar.gz" "${1%/}"; }
alias decompress='tar -xzf'

# SSH port forwarding: fip host port... / dip port... / lip
fip() {
	(( $# < 2 )) && { echo "Usage: fip <host> <port1> [port2] ..."; return 1; }
	local host=$1 port
	shift
	for port in "$@"; do
		ssh -f -N -L "${port}:localhost:${port}" "$host" && echo "Forwarding localhost:$port -> $host:$port"
	done
}
dip() {
	(( $# == 0 )) && { echo "Usage: dip <port1> [port2] ..."; return 1; }
	local port
	for port in "$@"; do
		pkill -f "ssh.*-L ${port}:localhost:${port}" && echo "Stopped forwarding port $port" || echo "No forwarding on port $port"
	done
}
lip() { pgrep -lf "ssh.*-L [0-9]+:localhost:[0-9]+" || echo "No active forwards"; }

# ssh: clean up terminal modes a dropped remote tmux/nvim left armed, and reconnect
# interactive sessions that drop after being up 30s+ (Omarchy's ssh-reconnect)
ssh() {
	local rc started=$SECONDS
	command ssh "$@"
	rc=$?
	[[ -t 1 ]] || return $rc
	_ssh_disarm
	if (( rc != 255 )) || [[ ! -t 0 ]] || ! _ssh_interactive "$@" || (( SECONDS - started < 30 )); then
		return $rc
	fi
	(
		while true; do
			echo "Connection lost. Reconnecting (Ctrl-C to stop)..."
			sleep 2
			command ssh "$@"
			rc=$?
			_ssh_disarm
			(( rc != 255 )) && exit $rc
		done
	)
}
_ssh_disarm() { printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[?1049l\e[?25h'; }
# true for a destination and no remote command (letters are ssh options that take a value)
_ssh_interactive() {
	local value_opts="BbcDEeFIiJLlmOoPpQRSWw" arg letters i dest="" opts_done=""
	local -a args=("$@")
	while (( $# )); do
		arg=$1
		shift
		if [[ -z $opts_done && $arg == "--" ]]; then
			opts_done=1
		elif [[ -z $opts_done && $arg == -?* ]]; then
			letters=${arg#-}
			for (( i = 1; i <= ${#letters}; i++ )); do
				if [[ $value_opts == *"${letters[i]}"* ]]; then
					(( i == ${#letters} )) && shift
					break
				fi
			done
		elif [[ -z $dest ]]; then
			dest=$arg
		else
			return 1
		fi
	done
	[[ -n $dest ]] || return 1
	# a RemoteCommand from ssh_config would replay on reconnect too
	local resolved
	resolved=$(command ssh -G "${args[@]}" 2>/dev/null) || return 1
	! grep -i '^remotecommand ' <<<"$resolved" | grep -qvi '^remotecommand none$'
}


# machine-local overrides, not in the repo
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
