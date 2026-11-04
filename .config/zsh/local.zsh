# Personal shell settings (ported from .bashrc in github.com/RyanAHayden/dotfiles)
export MANPAGER='nvim +Man!'
path=("$HOME/bin" $path)

# c = claude (cld wrapper if installed)
command -v cld >/dev/null && alias c=cld || alias c=claude

# t [session] = attach (to named session if given), else new "Work"
t() { tmux attach ${1:+-t "$1"} || tmux new -s "${1:-Work}"; }
