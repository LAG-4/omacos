# OMacOS interactive shell environment. This file is sourced from one marked
# block in ~/.zshrc so uninstall can remove the integration without replacing
# unrelated edits.

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export MANPAGER="${MANPAGER:-sh -c 'col -bx | bat -l man -p'}"

command -v eza >/dev/null 2>&1 && alias ls='eza --group-directories-first --icons=auto'
command -v eza >/dev/null 2>&1 && alias lsa='eza -a --group-directories-first --icons=auto'
command -v eza >/dev/null 2>&1 && alias lt='eza --tree --level=2 --icons=auto'
command -v eza >/dev/null 2>&1 && alias lta='eza -a --tree --level=2 --icons=auto'
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never'
command -v nvim >/dev/null 2>&1 && alias n='NVIM_APPNAME=omacos/nvim nvim'

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
  ff() {
    local selected
    selected=$(fd --type f --hidden --exclude .git | fzf --preview 'bat --color=always --style=numbers --line-range=:300 {}') || return
    ${EDITOR:-nvim} "$selected"
  }
fi

command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

compress() {
  if (( $# != 1 )); then
    print -u2 "Usage: compress FILE_OR_DIRECTORY"
    return 1
  fi
  tar -czf "${1:t}.tar.gz" "$1"
}

decompress() {
  if (( $# != 1 )) || [[ $1 != *.tar.gz && $1 != *.tgz ]]; then
    print -u2 "Usage: decompress ARCHIVE.tar.gz"
    return 1
  fi
  tar -xzf "$1"
}

tdl() {
  local agent=${1:-${OMACOS_AGENT:-codex}}
  local session=${PWD:t}
  tmux new-session -d -s "$session" -c "$PWD" "${EDITOR:-nvim} ." 2>/dev/null || true
  tmux split-window -h -t "$session:0" -c "$PWD" "$agent"
  tmux split-window -v -t "$session:0.0" -c "$PWD"
  tmux select-layout -t "$session:0" main-vertical
  tmux attach-session -t "$session"
}

tds() {
  local session=${PWD:t}
  tmux new-session -d -s "$session" -c "$PWD" "${EDITOR:-nvim} ." 2>/dev/null || true
  tmux split-window -h -t "$session:0" -c "$PWD" "git diff --stat; zsh"
  tmux split-window -v -t "$session:0.0" -c "$PWD"
  tmux split-window -v -t "$session:0.1" -c "$PWD" "${OMACOS_AGENT:-codex}"
  tmux select-layout -t "$session:0" tiled
  tmux attach-session -t "$session"
}

tsl() {
  local pane_count=${1:-4}
  local pane_command=${2:-${OMACOS_AGENT:-codex}}
  local session="swarm-${PWD:t}"
  tmux new-session -d -s "$session" -c "$PWD" "$pane_command"
  local pane_number=2
  while (( pane_number <= pane_count )); do
    tmux split-window -t "$session:0" -c "$PWD" "$pane_command"
    tmux select-layout -t "$session:0" tiled
    (( pane_number += 1 ))
  done
  tmux attach-session -t "$session"
}
