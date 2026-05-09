if [[ ":$FPATH:" != *":$HOME/.zsh/completions:"* ]]; then
  export FPATH="$HOME/.zsh/completions:$FPATH"
fi

path_prepend() {
  [[ -d "$1" ]] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"
path_prepend "/opt/homebrew/bin"
path_prepend "/opt/homebrew/sbin"
path_prepend "/usr/local/sbin"

if [[ -r "$HOME/.local/bin/env" ]]; then
  . "$HOME/.local/bin/env"
fi

export MISE_ENV=development
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

export ZSH="$HOME/.oh-my-zsh"
REPORTTIME=30
ZSH_THEME="kafeitu"
zstyle ':omz:update' mode disabled
DISABLE_UNTRACKED_FILES_DIRTY="true"
plugins=(git)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

export EDITOR="vim"
export TERM=xterm-256color
export GOPATH="$HOME/go"

function git_prompt_info() {
  local ref stripped_ref
  ref=$(command git symbolic-ref --quiet HEAD 2>/dev/null) || return
  stripped_ref="${ref#refs/heads/}"
  echo "${ZSH_THEME_GIT_PROMPT_PREFIX}${stripped_ref}${ZSH_THEME_GIT_PROMPT_SUFFIX} "
}

if [[ -n "${PYENV_ROOT:-}" && -x "$PYENV_ROOT/bin/pyenv" ]]; then
  pyenv() {
    unset -f pyenv
    eval "$("$PYENV_ROOT/bin/pyenv" init --path)"
    eval "$("$PYENV_ROOT/bin/pyenv" init -)"
    pyenv "$@"
  }
fi

alias result="echo $?"
alias vim="vim -p"
alias ls="eza"
alias gs="git status"
alias gdw="gd -w"
alias gdd="gd --no-ext-diff"
alias gdf="gd --no-ext-diff | diff-so-fancy"
alias gdfw="gd -w --no-ext-diff | diff-so-fancy"
alias gddw="gd -w --no-ext-diff"
alias gitsearch="git log --oneline -S"
alias vs="code"
alias godark="printf '\\033]50;SetProfile=Default\\a'"
alias golight="printf '\\033]50;SetProfile=DefaultLight\\a'"
alias gitl="git log --pretty=oneline | head -n 10"
alias gitll="git log --pretty=oneline | head -n 25"
alias o="open -a"
alias tickle="git status -s | cut -c4- | xargs touch"
alias add250ChangedFilesToGit="gs -s | head -n 250 | awk '{print $2}' | xargs git add"
alias cat="bat"
alias pingme="terminal-notifier -message 'ping' -title 'ping'; printf '\\a'"

gfb() {
  if [[ -z "$1" ]]; then
    echo "Usage: gfb <branchname>"
    return 1
  fi

  git fetch origin "+refs/heads/${1}:refs/remotes/origin/${1}"
}

compdef _git gfb=git-fetch

autoload -Uz add-zsh-hook

my_preexec_timer() {
  __cmd_start_time=$SECONDS
}

my_precmd_bell() {
  if [[ -n "${__cmd_start_time:-}" ]]; then
    local elapsed=$((SECONDS - __cmd_start_time))
    (( elapsed > 10 )) && printf "\a"
    unset __cmd_start_time
  fi
}

add-zsh-hook preexec my_preexec_timer
add-zsh-hook precmd my_precmd_bell

fzf_init_widget() {
  unfunction fzf_init_widget 2>/dev/null
  [[ -r "$HOME/.fzf.zsh" ]] && source "$HOME/.fzf.zsh"
  zle "$@"
}

zle -N fzf_init_widget
bindkey "^R" fzf_init_widget
bindkey "^T" fzf_init_widget
bindkey "^[C" fzf_init_widget

export NVM_DIR="$HOME/.nvm"

lazy_load_nvm() {
  unset -f nvm node npm npx pnpm yarn
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"
}

nvm() { lazy_load_nvm; nvm "$@"; }
node() { lazy_load_nvm; node "$@"; }
npm()  { lazy_load_nvm; npm "$@"; }
npx()  { lazy_load_nvm; npx "$@"; }
pnpm() { lazy_load_nvm; pnpm "$@"; }
yarn() { lazy_load_nvm; yarn "$@"; }

export PNPM_HOME="$HOME/Library/pnpm"
path_prepend "$PNPM_HOME"

if [[ -s "$HOME/.bun/_bun" ]]; then
  source "$HOME/.bun/_bun"
fi

export BUN_INSTALL="$HOME/.bun"
path_prepend "$BUN_INSTALL/bin"

if [[ -r "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi

unset -f path_prepend
