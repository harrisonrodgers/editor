# https://github.com/unixorn/awesome-zsh-plugins

# TODO: use stuff from https://git.forestier.app/HorlogeSkynet/dotfiles/src/commit/dd73214f6cc35cbda717685cb17932568284ce1f/.zshrc

source ~/.nix-profile/etc/profile.d/nix.sh
source ~/.config/zsh/zplug/init.zsh

eval "$(direnv hook zsh)"

## History
HISTFILE=$ZDOTDIR/.zsh_history
HISTSIZE=500000
SAVEHIST=$HISTSIZE
setopt EXTENDED_HISTORY       # Write the history file in the ':start:elapsed;command' format.  setopt INC_APPEND_HISTORY     # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY          # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS       # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS   # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS      # Do not display a previously found event.
setopt HIST_IGNORE_SPACE      # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS      # Do not write a duplicate event to the history file.
setopt HIST_VERIFY            # Do not execute immediately upon history expansion.
setopt HIST_BEEP              # Beep when accessing non-existent history.

## Profile
# not sure why but git doesn't seem to use PATH to find these
#export EDITOR='$HOME/.nix-profile/bin/nvim'
#export VISUAL='$HOME/.nix-profile/bin/nvim'
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'

# Default PS1
PS1='\[\033[01m\]\[\033[01;33m\]\t \u@\h\[\033[00m\]\[\033[01m\]: \[\033[01;32m\]\w\[\033[00m\]\n\[\033[01;33m\]$\[\033[00m\] '

# Enable Colors
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Muscle Memory
alias vim='nvim'
alias ls='exa --git --binary'
alias cat='bat'

## Prompt
export STARSHIP_CONFIG=~/.config/starship/starship.toml
eval "$(starship init zsh)"

## Dircolors
# Selenized dircolors (just default with one override)
export LS_COLORS="$LS_COLORS:ow=1;7;34:st=30;44:su=30;41"

## Syntax
zplug "zsh-users/zsh-syntax-highlighting", defer:2

## Man colors
zplug "jan-warchol/selenized", from:github, use:"other-apps/selenized-man/selenized-mono-man.plugin.zsh"

# Less Colors (from "jan-warchol/selenized")
LESS_TERMCAP_mb=$(printf "\e[1;37m")
LESS_TERMCAP_md=$(printf "\e[1;37m")
LESS_TERMCAP_me=$(printf "\e[0m")
LESS_TERMCAP_se=$(printf "\e[0m")
LESS_TERMCAP_ue=$(printf "\e[0m")

# Less colors (source code highlighting, warning it may be slow so use `less -L` to disable)
export LESSOPEN="| bat --color=always %s"
export LESS='-R --mouse --wheel-lines=5 --quit-if-one-screen'

## Completion
autoload -Uz compinit; compinit
#zstyle ':completion:*' menu select                 # autocompletion with an arrow-key driven interface
setopt COMPLETE_ALIASES                            # autocompletion of command line switches for aliases
zstyle ':completion::complete:*' gain-privileges 1 # autocompletion of privileged environments in privileged commands
#zplug "zsh-users/zsh-history-substring-search", defer:3

# FZF
source ~/.config/zsh/fzf/completion.zsh
source ~/.config/zsh/fzf/key-bindings.zsh
export FZF_DEFAULT_COMMAND="rg --files --hidden"
# --no-height
export FZF_DEFAULT_OPTS="
  --height 90%
  --no-reverse
  --color=bg+:#e9e4d0,bg:#fbf3db,spinner:#009c8f,hl:#0072d4:bold
  --color=fg:#53676d,header:#0072d4,info:#489100,pointer:#009c8f
  --color=marker:#009c8f,fg+:#c25d1e,prompt:#489100,hl+:#0072d4"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:hidden:wrap --bind '?:toggle-preview'"
export FZF_CTRL_T_OPTS="--preview '((test -f {} && bat --color always {}) || tree -C {}) 2> /dev/null | head -200'"

## FZF-Tab Completion (make sure it is last plugin so it's key-bindings win)
zplug "Aloxaf/fzf-tab", from:github, use:"fzf-tab.plugin.zsh"
zstyle ':completion:*:descriptions' format '[%d]'
# do not sort git checkout or commit
zstyle ":completion:*:git-checkout:*" sort false
zstyle ":completion:*:git-commit:*" sort false
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:*' default-color $'\033[92m'
# give a preview of directory by exa when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'

## Keys
# Ensure delete key works as expected
bindkey "\e[3~" delete-char
# Disable XON/XOFF flow control which takes over ctrl+q and ctrl+s (i want normal ctrl+s for forward history search)
#stty -ixon

## VI Mode
#bindkey -v
# Ensure backspace works in Vi mode
#bindkey -v '^?' backward-delete-char
# Retain CTRL+R and CTRL+S in Vi mode
#bindkey -v "^R" history-incremental-search-backward
#bindkey -v "^S" history-incremental-search-forward

alias ca='if ! test -f tasks.py ; then echo "Not a supported repo, no tasks.py found." && return 1 ; fi ; conda deactivate && basename=`basename $PWD` && conda activate $basename'

alias cr='if ! test -f tasks.py ; then echo "Not a supported repo, no tasks.py found." && return 1 ; fi ; conda deactivate && basename=`basename $PWD` && conda env remove -n $basename && rm -rf ~/.conda/envs/$basename 2>/dev/null ; conda create -n $basename python=3.8.10 invoke ipython pylint flake8-bugbear flake8-builtins flake8-rst flake8-rst-docstrings flake8-docstrings jinja2 pyyaml --yes --quiet && conda activate $basename && inv bootstrap develop hooks' # && conda clean --packages --tarballs --force-pkgs-dirs --yes --quiet'
alias cr36='if ! test -f tasks.py ; then echo "Not a supported repo, no tasks.py found." && return 1 ; fi ; conda deactivate && basename=`basename $PWD` && conda env remove -n $basename && rm -rf ~/.conda/envs/$basename 2>/dev/null ; conda create -n $basename python=3.6.8 invoke ipython pylint flake8-bugbear flake8-builtins flake8-rst flake8-rst-docstrings flake8-docstrings jinja2 pyyaml --yes --quiet && conda activate $basename && inv bootstrap develop hooks' # && conda clean --packages --tarballs --force-pkgs-dirs --yes --quiet'

alias crclean='if ! test -f tasks.py ; then echo "Not a supported repo, no tasks.py found." && return 1 ; fi ; conda deactivate && basename=`basename $PWD` && conda env remove -n $basename && rm -rf ~/.conda/envs/$basename 2>/dev/null ; conda create -n $basename python=3.8.10 invoke jinja2 pyyaml --yes --quiet && conda activate $basename && inv bootstrap develop hooks ' # && conda clean --packages --tarballs --force-pkgs-dirs --yes --quiet'
alias crclean36='if ! test -f tasks.py ; then echo "Not a supported repo, no tasks.py found." && return 1 ; fi ; conda deactivate && basename=`basename $PWD` && conda env remove -n $basename && rm -rf ~/.conda/envs/$basename 2>/dev/null ; conda create -n $basename python=3.6.8 invoke jinja2 pyyaml --yes --quiet && conda activate $basename && inv bootstrap develop hooks ' # && conda clean --packages --tarballs --force-pkgs-dirs --yes --quiet'

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/conda/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
        . "/opt/conda/etc/profile.d/conda.sh"
    else
        export PATH="/opt/conda/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<

## Zplug
#zplug 'zplug/zplug', hook-build:'zplug --self-manage'
if ! zplug check; then
    zplug install
fi
zplug load
