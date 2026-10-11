## FIRST ###############################################################################################################

# Nix
source ~/.local/state/nix/profile/etc/profile.d/nix.sh # nix keeps its profile in XDG_STATE_HOME (see the Dockerfile)

########################################################################################################################

# Editor defaults
export EDITOR='nvim'
export VISUAL='nvim'

# Set XDG Base Directory Specification
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_BIN_HOME="${HOME}/.local/bin"

typeset -U path # keep PATH entries unique, so nested shells (tmux, subshells) don't stack duplicates
path=("${XDG_BIN_HOME}" $path) # assign via the array: assigning the PATH string would bypass the uniqueness

# Use XDG Base Directory Specification: https://wiki.archlinux.org/title/XDG_Base_Directory
export INPUTRC="${XDG_CONFIG_HOME}/readline/inputrc"
export MYPY_CACHE_DIR="${XDG_CACHE_HOME}/mypy"
export RUFF_CACHE_DIR="${XDG_CACHE_HOME}/ruff"
export PYTHONPYCACHEPREFIX="${XDG_CACHE_HOME}/python"
export LESSHISTFILE="${XDG_STATE_HOME}/less/history"
export PYTHON_HISTORY="${XDG_STATE_HOME}/python/history"
export SQLITE_HISTORY="${XDG_STATE_HOME}/sqlite/history"
export RUMDL_CACHE_DIR="${XDG_CACHE_HOME}/rumdl" # else `rumdl fmt` (nvim's format on save) writes .rumdl_cache/ into the project
export ANSIBLE_HOME="${XDG_DATA_HOME}/ansible"   # else ansible-lint creates ~/.ansible
export WGETRC="${XDG_CONFIG_HOME}/wget/wgetrc"    # moves wget's HSTS cache (~/.wget-hsts) to ~/.local/state

# Create the base dirs, plus the parent dirs of the history files above (less/python/sqlite will not create them)
mkdir -p \
    "${XDG_CONFIG_HOME}" \
    "${XDG_CACHE_HOME}" \
    "${XDG_DATA_HOME}" \
    "${XDG_BIN_HOME}" \
    "${XDG_CACHE_HOME}"/{zsh,mypy,ruff,python} \
    "${XDG_STATE_HOME}"/{zsh,less,python,sqlite}

# GNU ls: use dircolors if available
if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b ~/.dircolors 2>/dev/null || dircolors -b)"
    # Selenized dircolors (just default with one override)
    export LS_COLORS="$LS_COLORS:ow=1;7;34:st=30;44:su=30;41"
fi

# Colorized output
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Terminal behavior
stty -ixon 2>/dev/null # Disable XON/XOFF flow control (Ctrl+S/Ctrl+Q) so Ctrl+S can be used for forward history search

# History behavior
export HISTFILE="${XDG_STATE_HOME}/zsh/history"
export HISTSIZE=10000        # Keep 10k entries in memory
export SAVEHIST=$HISTSIZE    # Save the same number to HISTFILE
setopt HIST_IGNORE_DUPS      # Ignore duplicate commands
setopt HIST_IGNORE_ALL_DUPS  # Remove older duplicate entries
setopt HIST_REDUCE_BLANKS    # Remove extra spaces before saving
setopt HIST_SAVE_NO_DUPS     # Don't save command if it's already in history
setopt HIST_FIND_NO_DUPS     # Don't find duplicates in reverse-i-search
setopt SHARE_HISTORY         # Share history between sessions
#setopt APPEND_HISTORY       # Append to history file on exit
#setopt INC_APPEND_HISTORY   # Append immediately, not just on exit
setopt EXTENDED_HISTORY      # Save timestamp with history
setopt INTERACTIVE_COMMENTS  # Allow comments (#) in interactive shells.

# Warn about background jobs before exit
setopt CHECK_JOBS

# Enable recursive globbing (**)
setopt GLOB_STAR_SHORT

# Allow case-insensitive globbing
setopt NO_CASE_GLOB

# Prompt
export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/starship.toml"
eval "$(starship init zsh)"

# Completion
autoload -Uz compinit                              # load then initialize completion system
zstyle ':completion:*' menu select                 # autocompletion with an arrow-key driven interface
zstyle ':completion::complete:*' gain-privileges 1 # autocompletion of privileged environments in privileged commands
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME}/zsh/zcompcache" # set cache file location
setopt COMPLETE_ALIASES                            # autocompletion of command line switches for aliases
compinit -d "${XDG_CACHE_HOME}/zsh/zcompdump"

# Keys
bindkey -e                  # Enable emacs mode (should be default) to permit Control+R for reverse history search
bindkey "\e[3~" delete-char # Bind delete key to delete-char function as some terminals do not map it correctly by default

# Muscle Memory
alias vim='nvim'
alias ls='eza --git --binary'
alias cat='bat'

# Less/man colors, tuned for Selenized light (ANSI indices, so the terminal palette sets the real colors)
export LESS_TERMCAP_mb=$'\e[1;32m'    # blink -> bold green
export LESS_TERMCAP_md=$'\e[1;32m'    # bold (headings, options) -> bold green
export LESS_TERMCAP_me=$'\e[0m'       # end bold/blink
export LESS_TERMCAP_so=$'\e[7m'       # standout (status line, search hits) -> reverse video
export LESS_TERMCAP_se=$'\e[0m'       # end standout
export LESS_TERMCAP_us=$'\e[4;31m'    # underline (arguments) -> underlined red
export LESS_TERMCAP_ue=$'\e[0m'       # end underline

########################################################################################################################

# Less colors (source code highlighting, warning it may be slow so use `less -L` to disable)
export LESSOPEN="| bat --color=always %s"
export LESS='-R --mouse --wheel-lines=5 --quit-if-one-screen'

# Direnv (applies .envrc when cd'ing into a folder)
eval "$(direnv hook zsh)"

# sqruff (SQL lint + format) only reads a config file in the directory it runs in. When there is none (.sqruff,
# .sqruff.ini, sqruff.toml, .sqlfluff, pyproject.toml [tool.sqruff]), use ~/.config/sqruff/.sqruff (postgres, line
# length 120: the same one nvim uses) and say so on stderr. Left alone: --config given, `sqruff lsp` (its server
# ignores --config), --help / --version.
sqruff() {
    local user_config="${XDG_CONFIG_HOME}/sqruff/.sqruff"
    if [[ ! -f "$user_config" || " $* " == *" --config"* || "$1" == (lsp|-h|--help|-V|--version) ]] \
        || [[ -f .sqruff || -f .sqruff.ini || -f sqruff.toml || -f .sqlfluff ]] \
        || { [[ -f pyproject.toml ]] && grep -q '^\[tool\.sqruff' pyproject.toml; }
    then
        command sqruff "$@"
    else
        print -u2 "sqruff: no sqruff config in this directory, using --config ${user_config/#$HOME/~}"
        command sqruff --config "$user_config" "$@"
    fi
}

# Micromamba
,m() {
    micromamba "$@"
}

# Repo: cd to /sandbox/${USER}/repos/<repo>, or to the repos dir itself with no args
,r() {
    local repos="/sandbox/${USER}/repos"
    if [[ $# -eq 0 ]]
    then
        cd "$repos"
    elif [[ -d "$repos/$1" ]]
    then
        cd "$repos/$1"
    else
        echo "No such repo: $repos/$1" >&2
        return 1
    fi
}

_comma_r() {
    local -a repos
    repos=( /sandbox/${USER}/repos/*(N/:t) )
    compadd -a repos
}
compdef _comma_r ,r

# Conda: Activate
,ca() {
    if ! test -f tasks.py
    then
        echo "Not a supported repo, no tasks.py found."
        return 1
    else
        local env_name="${PWD:t}"
        micromamba deactivate
        micromamba activate "$env_name"
        rehash
    fi
}

# Conda: Recreate
,cr() {
    if ! test -f tasks.py
    then
        echo "Not a supported repo, no tasks.py found."
        return 1
    else
        local env_name="${PWD:t}"
        micromamba deactivate
        # micromamba env remove -n "$env_name" # use rm instead to avoid complaint if non-existant
        rm -rf "${MAMBA_ROOT_PREFIX:?}/envs/${env_name:?}" 2>/dev/null
        micromamba create -n "$env_name" python=3.12 invoke jinja2 pyyaml --yes --quiet
        micromamba activate "$env_name"
        inv bootstrap develop hooks
        rehash
        # micromamba clean --packages --tarballs --force-pkgs-dirs --yes --quiet
    fi
}

# FZF
source ~/.config/zsh/fzf/completion.zsh
source ~/.config/zsh/fzf/key-bindings.zsh
export FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git'" # hidden files, but not git's internals
# --no-height
export FZF_DEFAULT_OPTS="
  --height 90%
  --no-reverse
  --color=bg+:#e9e4d0,bg:#fbf3db,spinner:#009c8f,hl:#3a4d53:bold
  --color=fg:#53676d,header:#0072d4,info:#489100,pointer:#009c8f
  --color=marker:#009c8f,fg+:#c25d1e,prompt:#489100,hl+:#3a4d53:bold"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:hidden:wrap --bind '?:toggle-preview'"
export FZF_CTRL_T_OPTS="--preview '((test -f {} && bat --color always {}) || tree -C {}) 2> /dev/null | head -200'"

## FZF-Tab Completion (load after compinit, before syntax highlighting)
source "${XDG_STATE_HOME}/nix/profile/share/fzf-tab/fzf-tab.plugin.zsh"

zstyle ':completion:*:descriptions' format '[%d]'
# do not sort git checkout or commit
zstyle ":completion:*:git-checkout:*" sort false
zstyle ":completion:*:git-commit:*" sort false
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# fzf-tab's defaults are bright colors meant for dark terminals; use the selenized light palette instead (truecolor).
# Plain candidates get fg_0. Group headers/candidates are colored by group number (1st group gets the 1st color, ...) and
# fzf-tab does not wrap around: groups past the end of the list get no color. So groups 1-8 are the 8 selenized hues
# (blue first) and groups 9-16 are hues halfway between neighbouring selenized hues, at the same lightness/chroma.
# Every escape starts with 0; (reset) because fzf carries ANSI state over from the previous line, so an unreset bold or
# color would leak into the following lines.
zstyle ':fzf-tab:*' default-color $'\033[0;38;2;83;103;109m'
() {
  local -a rgb=(
    "0;114;212" "72;145;0" "173;137;0" "202;72;152" "210;33;45" "0;156;143" "194;93;30" "135;98;198" # selenized
    "0;142;181" "135;141;0" "210;51;106" "95;105;212" "187;115;0" "0;154;99" "171;85;183" "204;69;28" # in-between hues
  )
  local -a colors
  local c
  for c in $rgb; do colors+=($'\033[0;38;2;'$c'm'); done
  zstyle ':fzf-tab:*' group-colors "${colors[@]}"
}
# fzf-tab clears FZF_DEFAULT_OPTS by default, which drops the selenized --color settings above (the selected row and
# gutter then fall back to fzf's own, dark-looking colors); its own --height/--layout flags still win over ours
zstyle ':fzf-tab:*' use-fzf-default-opts yes
# give a preview of directory by eza when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'

## Micromamba
# the nix package wraps the binary as ".mamba-wrapped", which the hook rejects (name must be micromamba),
# so force the detected name or the micromamba shell function never gets defined
# The hook output is static text, but generating it runs the binary (~15 ms), so cache it and source the file (~1 ms).
# micromamba is pinned by the image so the cache is never invalidated; delete it to regenerate (e.g. after an upgrade).
micromamba_hook="${XDG_CACHE_HOME}/zsh/micromamba-hook.zsh"
if [[ ! -s "$micromamba_hook" ]]; then
    micromamba shell hook --shell zsh | sed 's/^__exe_name=.*/__exe_name=micromamba/' >| "$micromamba_hook"
fi
source "$micromamba_hook"
unset micromamba_hook

## LAST ################################################################################################################

## Syntax (highlighting of commands in the prompt, spot syntax errors before running) PLACE NEAR END OF .zshrc
source "${XDG_STATE_HOME}/nix/profile/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
