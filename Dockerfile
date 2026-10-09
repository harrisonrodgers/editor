FROM ubuntu:22.04

# The ARG applies to all `apt` use in RUN, but won't persist into the container.
ARG DEBIAN_FRONTEND=noninteractive

## TERM (matters to apps like ZSH/TMUX/...) ############################################################################
ENV TERM=xterm-256color \
    COLORTERM=truecolor

## LANG ################################################################################################################
ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

## SHELL ###############################################################################################################
# Fail a RUN if any command in a pipe fails (not just the last one), e.g. `curl ... | sh` with a failed download.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

## UNMINIMIZE UBUNTU ###################################################################################################
# unminimize asks several questions (its own, then apt's "Do you want to continue? [Y/n]"), so answer all of them with
# `yes`. `yes` gets SIGPIPE when unminimize exits, which pipefail reports as exit 141, so `|| true` ignores yes's status
# only; a failure of unminimize itself still fails the build.
RUN { yes || true; } | unminimize

## INSTALL #############################################################################################################
RUN apt-get update \
    && apt-get -y install \
        sudo \
        tzdata \
        build-essential \
        openssh-client \
        man-db \
        git-man \
        manpages \
        manpages-dev \
        manpages-posix \
        manpages-posix-dev \
        curl \
        ncurses-term \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log


## USER SETUP ##########################################################################################################
ENV USER=harrison.rodgers \
    GROUP=harrison.rodgers \
    UID=501211 \
    GID=1001
ENV HOME="/home/${USER}"
# useradd -l (--no-log-init): with a high UID, the lastlog/faillog entries make those files huge, and they bloat the image
RUN groupadd -g "${GID}" "${GROUP}" \
    && useradd -l -u "${UID}" -g "${GID}" -d "${HOME}" -s /bin/sh --create-home -k /dev/null "${USER}" \
    # password-less sudo inside the container
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

## Sandbox #############################################################################################################
RUN mkdir -p "/sandbox/${USER}" \
    && chown "${UID}:${GID}" "/sandbox/${USER}"

## USER ACTIVATE FOR REST OF DOCKERFILE (note: after this point, need to use sudo) #####################################
USER ${UID}:${GID}
WORKDIR ${HOME}

## INSTALL NIX #########################################################################################################
RUN sudo mkdir -p /etc/nix && sudo sh -c 'printf "experimental-features = nix-command flakes" > /etc/nix/nix.conf'

ENV PATH="${HOME}/.nix-profile/bin:${PATH}" \
    NIXPKGS_ALLOW_UNFREE=1

RUN mkdir -p "${HOME}/.config/nixpkgs" \
    && echo '{ allowUnfree = true; }' > "${HOME}/.config/nixpkgs/config.nix"

RUN curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon

## PACKAGES ############################################################################################################
RUN nix profile add --impure \
# shell & terminal
        # shell & prompt
        nixpkgs#zsh \
        nixpkgs#zsh-fzf-tab \
        nixpkgs#zsh-syntax-highlighting \
        nixpkgs#starship \
        # nixpkgs#zsh-powerlevel10k # consider, faster, though zsh only
        # terminal multiplexer
        nixpkgs#tmux \
# editors
        # nano as a fallback; neovim is installed below, wrapped with nvim-treesitter
        nixpkgs#nano \
        # compiler, used by nvim to build tree-sitter parsers
        nixpkgs#gcc \
        # tree-sitter CLI, required by nvim-treesitter (:checkhealth) to build/install parsers
        nixpkgs#tree-sitter \
# cli utilities
        # core cli
        nixpkgs#git \
        nixpkgs#less \
        nixpkgs#gawk \
        nixpkgs#wget \
        nixpkgs#curl \
        nixpkgs#tree \
        nixpkgs#gnutar \
        nixpkgs#zip \
        nixpkgs#unzip \
        # modern replacements: grep, find, cat, ls
        nixpkgs#ripgrep \
        # nixpkgs#ripgrep-all \
        nixpkgs#fd \
        nixpkgs#bat \
        nixpkgs#eza \
        # fuzzy finder
        nixpkgs#fzf \
        # smarter cd that learns your most used directories
        nixpkgs#zoxide \
        # per-directory env vars (.envrc)
        nixpkgs#direnv \
        # bulk rename files in your editor (qmv, imv)
        nixpkgs#renameutils \
        # determine types of files
        nixpkgs#file \
        # reference / man pages (using apt's manpages instead as that will cover the non-nix stuff also)
        # nixpkgs#man \
        # nixpkgs#manpages \
        # nixpkgs#stdman \
        # nixpkgs#llvm-manpages \
        # nixpkgs#clang-manpages \
        # nixpkgs#man-pages \
        # nixpkgs#posix_man_pages \
# data & documents
        # structured data: query json, turn command output into json, make json greppable, query yaml
        nixpkgs#jq \
        nixpkgs#jc \
        nixpkgs#gron \
        nixpkgs#yq-go \
        # convert hcl2 (nomad, terraform) to json so it's easier for claude to read
        nixpkgs#hcl2json \
        # simple statistics (mean, stddev, ...) from numbers on stdin
        nixpkgs#sta \
        # convert between markup formats (markdown, html, docx, ...)
        nixpkgs#pandoc \
        # nixpkgs#plantuml \  # TODO: uncomment later, for now avoid as it needs building on arm
# code search, diffs & stats
        # search and rewrite code using its ast
        nixpkgs#ast-grep \
        # diff viewers: pager for git output, and structural diff that understands syntax
        nixpkgs#delta \
        nixpkgs#difftastic \
        # count lines of code
        nixpkgs#tokei \
        nixpkgs#cloc \
# language servers, linters & formatters
        # language servers (for neovim)
        nixpkgs#ty \
        nixpkgs#bash-language-server \
        nixpkgs#yaml-language-server \
        nixpkgs#vim-language-server \
        nixpkgs#dockerfile-language-server \
        nixpkgs#lua-language-server \
        nixpkgs#jinja-lsp \
        # html, css, json, eslint
        nixpkgs#vscode-langservers-extracted \
        # nixpkgs#nodePackages.neovim \
        # python: lint/format, and find unused functions/variables/...
        nixpkgs#ruff \
        nixpkgs#python314Packages.vulture \
        # shell: lint and format
        nixpkgs#shellcheck \
        nixpkgs#shfmt \
        # lua: format
        nixpkgs#stylua \
        # yaml, markdown, ansible
        nixpkgs#yamllint \
        nixpkgs#markdownlint-cli2 \
        nixpkgs#ansible-lint \
        # jinja2 templates: djlint (lint + format, HTML templates), j2lint (lint), jinja2-cli (render a template)
        nixpkgs#djlint \
        nixpkgs#j2lint \
        nixpkgs#jinja2-cli \
        # sql: lint and auto-format
        nixpkgs#sqlfluff \
        # dockerfiles
        nixpkgs#hadolint \
        # terraform .tf files
        nixpkgs#tflint \
        # .proto files: lint and check for breaking changes
        nixpkgs#buf \
        # xml: xmllint
        nixpkgs#libxml2 \
        # git commit message lint
        nixpkgs#gitlint \
        # spelling mistakes in code https://github.com/crate-ci/typos/blob/main/docs/comparison.md
        nixpkgs#typos \
        nixpkgs#typos-lsp \
        # broken link checker (markdown, html, ...)
        nixpkgs#lychee \
        # report on credential leaks: gitleaks git -v
        nixpkgs#gitleaks \
# debugging, profiling & monitoring
        # system inspection: processes, open files, network (netstat, ifconfig)
        nixpkgs#htop \
        nixpkgs#lsof \
        nixpkgs#net-tools \
        # log file viewer
        nixpkgs#lnav \
        # python sampling profiler, syscall tracer, debugger
        nixpkgs#py-spy \
        nixpkgs#strace \
        nixpkgs#gdb \
        # benchmark commands against each other
        nixpkgs#hyperfine \
        # network clients: websockets, grpc, dns (dig, nslookup)
        nixpkgs#websocat \
        nixpkgs#grpcurl \
        nixpkgs#bind \
        # promtool (check prometheus rules/configs, query a server)
        nixpkgs#prometheus.cli \
# containers & infrastructure
        # containers & kubernetes
        nixpkgs#docker \
        nixpkgs#kubectl \
        nixpkgs#kustomize \
        # explore docker image layers and find wasted space
        nixpkgs#dive \
        # NOTE: may want to skip as these take time to build and are likely not needed
        # nixpkgs#nomad \
        # nixpkgs#terraform \
# python
        # env manager (envs live in $MAMBA_ROOT_PREFIX) and fast pip/venv replacement
        nixpkgs#micromamba \
        nixpkgs#uv \
        # nixpkgs#python310Full \  # using micromamba envs instead
# container runtime & claude code
        # claude code sandbox dependencies
        nixpkgs#bubblewrap \
        nixpkgs#socat \
        # binary cache client (used at container start: `cachix use claude-code`)
        nixpkgs#cachix \
        # init process (PID 1, see ENTRYPOINT below): reaps zombie processes and forwards signals so `stop` is immediate
        nixpkgs#tini \
# cleanup (only shrinks the image if chained onto the same RUN as the installs)
    && nix store gc \
    && nix store optimise \
    && nix store verify --all --no-trust

## NEOVIM (wrapped with nvim-treesitter + all grammars/queries from nixpkgs) ###########################################
# `withAllGrammars` pulls in its parsers and queries only via a wrapped neovim, so install neovim that way.
# wrapRc = false: keep loading ~/.config/nvim/init.lua instead of a generated init.
RUN nix profile add --impure --expr \
    'let p = (builtins.getFlake "nixpkgs").legacyPackages.${builtins.currentSystem}; \
     in p.wrapNeovimUnstable p.neovim-unwrapped { \
          plugins = [ p.vimPlugins.nvim-treesitter.withAllGrammars ]; \
          wrapRc = false; \
        }'

## REMOVE python if it snuck in (as we use micromamba) #################################################################
#RUN sudo apt-get remove -y python3 \
#    && sudo apt-get -y autoremove

## MAN & COMPLETION (UPDATE DBS AFTER ALL THE ABOVE INSTALLS) ##########################################################
RUN sudo mandb --create

## CONFIG FILES ########################################################################################################
COPY --chown=${UID}:${GID} ["home", "${HOME}/"]
COPY --chown=${UID}:${GID} ["sandbox/conda", "/sandbox/${USER}/conda"]

## BAT THEME ###########################################################################################################
# register the custom selenized-light theme from home/.config/bat/themes
RUN bat cache --build

## NVIM SETUP ##########################################################################################################
# Plugins are managed by neovim's built-in vim.pack (see home/.config/nvim/lua/config/plugins.lua). The first headless
# start installs the latest upstream version of each (no lockfile is shipped); the second fails the build if the config errors.
RUN echo "Installing nvim plugins using vim.pack:" \
    && nvim --headless -c 'qa' \
    && echo "Checking the nvim config loads cleanly:" \
    && nvim --headless -c 'if v:errmsg != "" | echo v:errmsg | cquit 1 | endif' -c 'qa'

## TRESITTER SETUP (for now using nix pre-built source) ################################################################
#   # treesitter install (sync is slow, but safest way to do it automated)
#   && echo "Installing nvim-treesitter language parsers:" \
#   && nvim --headless -c "TSInstallSync all" -c "qa"

## ZSH #################################################################################################################
ENV ZDOTDIR="${HOME}/.config/zsh"

## PYTHON ##############################################################################################################
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTEST_ADDOPTS="-p no:cacheprovider"

## MICROMAMBA ##########################################################################################################
ENV MAMBA_ROOT_PREFIX="/sandbox/${USER}/conda" \
    CONDA_ENVS_PATH="/sandbox/${USER}/conda/envs" \
    CONDA_PKGS_DIRS="/sandbox/${USER}/conda/pkgs"

RUN mkdir -p "${HOME}/.cache/mamba/proc" \
    && mkdir -p "${CONDA_ENVS_PATH}" \
    && mkdir -p "${CONDA_PKGS_DIRS}"

## UV #################################################################################################################

ENV UV_PROJECT_ENVIRONMENT="/sandbox/${USER}/uv/venv" \
    UV_PYTHON_INSTALL_DIR="/sandbox/${USER}/uv/python" \
    UV_TOOL_BIN_DIR="/sandbox/${USER}/uv/tool_bin" \
    UV_TOOLS_DIR="/sandbox/${USER}/uv/tools" \
    UV_NO_CACHE=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_NO_DEV=1

# `uv tool install` puts executables in UV_TOOL_BIN_DIR, so it must be on PATH (a separate ENV, as a variable set in an
# ENV instruction can't be used by another variable in that same instruction)
ENV PATH="${UV_TOOL_BIN_DIR}:${PATH}"

RUN mkdir -p "${UV_PROJECT_ENVIRONMENT}" \
    && mkdir -p "${UV_PYTHON_INSTALL_DIR}" \
    && mkdir -p "${UV_TOOL_BIN_DIR}" \
    && mkdir -p "${UV_TOOLS_DIR}"

## Claude  #############################################################################################################

RUN mkdir -p "${HOME}/.claude" \
    && echo '{ "hasCompletedOnboarding": true }' > "${HOME}/.claude.json"

## CMD #################################################################################################################
# tini as PID 1: `sleep` alone ignores SIGTERM (so stopping waits for the kill timeout) and never reaps orphaned processes
ENTRYPOINT ["tini", "--"]
CMD ["sleep", "infinity"]
