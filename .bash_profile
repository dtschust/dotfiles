alias result="echo $?"
alias vim="vim -p"
alias ls="ls -G"
alias code="cd ~/wrk"
alias godark="echo -e '\033]50;SetProfile=Dark\a'"
alias golight="echo -e '\033]50;SetProfile=Light\a'"
alias gitl="git log --pretty=oneline | head"
# PS1="[\w] ~~Drew~~ \n$ "
PS1="[\w] "
# Set CLICOLOR if you want Ansi Colors in iTerm2 
export CLICOLOR=1

# Set colors to match iTerm2 Terminal Colors
export TERM=xterm-256color

if [ -f ~/.git-completion.bash ]; then
  . ~/.git-completion.bash
fi


# bash_prompt based on https://github.com/necolas/dotfiles/blob/master/shell/bash_prompt

# Base styles and color palette
# Solarized colors
# https://github.com/altercation/solarized/tree/master/iterm2-colors-solarized
BOLD=$(tput bold)
RESET=$(tput sgr0)
SOLAR_YELLOW=$(tput setaf 136)
SOLAR_ORANGE=$(tput setaf 166)
SOLAR_RED=$(tput setaf 124)
SOLAR_MAGENTA=$(tput setaf 125)
SOLAR_VIOLET=$(tput setaf 61)
SOLAR_BLUE=$(tput setaf 33)
SOLAR_CYAN=$(tput setaf 37)
SOLAR_GREEN=$(tput setaf 64)
SOLAR_WHITE=$(tput setaf 254)

style_user="\[${RESET}${SOLAR_MAGENTA}\]"
style_host="\[${RESET}${SOLAR_CYAN}\]"
style_path="\[${RESET}${SOLAR_VIOLET}\]"
style_chars="\[${RESET}${SOLAR_WHITE}\]"
style_branch="${SOLAR_ORANGE}"
style_money="\[${RESET}${SOLAR_GREEN}\]"

if [[ "$SSH_TTY" ]]; then
    # connected via ssh
    style_host="\[${BOLD}${SOLAR_RED}\]"
elif [[ "$USER" == "root" ]]; then
    # logged in as root
    style_user="\[${BOLD}${SOLAR_RED}\]"
fi

is_git_repo() {
    $(git rev-parse --is-inside-work-tree &> /dev/null)
}

is_git_dir() {
    $(git rev-parse --is-inside-git-dir 2> /dev/null)
}

get_git_branch() {
    local branch_name

    # Get the short symbolic ref
    branch_name=$(git symbolic-ref --quiet --short HEAD 2> /dev/null) ||
    # If HEAD isn't a symbolic ref, get the short SHA
    branch_name=$(git rev-parse --short HEAD 2> /dev/null) ||
    # Otherwise, just give up
    branch_name="(unknown)"

    printf $branch_name
}

# Git status information
prompt_git() {
    local git_info git_state uc us ut st

    if ! is_git_repo || is_git_dir; then
        return 1
    fi

    git_info=$(get_git_branch)

    # Check for uncommitted changes in the index
    if ! $(git diff --quiet --ignore-submodules --cached); then
        uc="${SOLAR_GREEN}+"
    fi

    # Check for unstaged changes
    if ! $(git diff-files --quiet --ignore-submodules --); then
        us="${SOLAR_RED}!"
    fi

    # Check for untracked files
    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        ut="${SOLAR_ORANGE}?"
    fi

    # Check for stashed files
    if $(git rev-parse --verify refs/stash &>/dev/null); then
        st="${SOLAR_YELLOW}$"
    fi

    git_state=$uc$us$ut$st

    # Combine the branch name and state information
    if [[ $git_state ]]; then
        git_info="$git_info${SOLAR_CYAN}[$git_state${SOLAR_CYAN}]"
    fi

    # You know you’re on `gh-pages`, right? *Right*?
    if [[ $git_info == "gh-pages" ]]; then
        style_branch="${SOLAR_BLUE}"
    fi

    # Don’t screw up `stable`.
    if [[ $git_info == *stable* ]]; then
        style_branch="${SOLAR_RED}"
    fi

    printf "${SOLAR_WHITE} on ${style_branch}${git_info}"
}

# Set the terminal title to the current working directory
# PS1="\[\033]0;\w\007\]"
# Build the prompt
# PS1="\n" # Newline
# PS1+="${style_host}\h" # Host
# PS1+="${style_chars}:" # :
# PS1+="${style_path}\w " # Working directory
# PS1+="${style_user}🙌  \u 🙌 " # Username
# PS1+="\$(prompt_git)" # Git details
# PS1+="\n" # Newline
# PS1+="${style_chars}\$ \[${RESET}\]" # (and reset color)
