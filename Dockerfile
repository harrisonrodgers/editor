FROM ubuntu:22.04

# The ARG applies to all `apt` use in RUN, but won't persist into the container.
ARG DEBIAN_FRONTEND=noninteractive

## TERM (matters to apps like ZSH/TMUX/...)
ENV TERM=xterm-256color \
    COLORTERM=truecolor

## LANG
ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

## SHELL
# Fail a RUN if any command in a pipe fails (not just the last one), e.g. `curl ... | sh` with a failed download.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

## UNMINIMIZE UBUNTU
RUN { yes || true; } | unminimize

## INSTALL
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

## USER SETUP
ENV USER=harrison.rodgers \
    GROUP=harrison.rodgers \
    UID=501211 \
    GID=1001
ENV HOME="/home/${USER}"
RUN groupadd -g "${GID}" "${GROUP}" \
    && useradd -l -u "${UID}" -g "${GID}" -d "${HOME}" -s /bin/sh --create-home -k /dev/null "${USER}" \
    # password-less sudo inside the container
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

## Sandbox
RUN mkdir -p "/sandbox/${USER}" \
    && chown "${UID}:${GID}" "/sandbox/${USER}"

## USER ACTIVATE FOR REST OF DOCKERFILE (note: after this point, need to use sudo)
USER ${UID}:${GID}
WORKDIR ${HOME}

## INSTALL NIX
# auto-optimise-store: hard-link identical files as each path is added, in every layer. Better than a one-off
# `nix store optimise`, which only covers paths present when it runs and links every file from earlier layers too
# (overlayfs copies a lower-layer file up into the new layer when it is hard-linked, re-adding it to the image).
# nix-path: resolve `<nixpkgs>` (nix-shell -p, nix repl) via the flake registry, as no channel is installed (see below).
RUN sudo mkdir -p /etc/nix \
    && printf "%s\n" \
    "experimental-features = nix-command flakes" \
    "use-xdg-base-directories = true" \
    "auto-optimise-store = true" \
    "nix-path = nixpkgs=flake:nixpkgs" \
    | sudo tee /etc/nix/nix.conf >/dev/null

ENV PATH="${HOME}/.local/state/nix/profile/bin:${PATH}" \
    NIXPKGS_ALLOW_UNFREE=1

RUN mkdir -p "${HOME}/.config/nixpkgs" \
    && echo '{ allowUnfree = true; }' > "${HOME}/.config/nixpkgs/config.nix"

## PACKAGES (nix, then nix packages, neovim and micromamba, all in one RUN so the store is deduped and cleaned as one layer)
# --no-channel-add: the installer would otherwise subscribe to nixpkgs-unstable and download a full nixpkgs copy
# (~210 MiB) that gc can never remove; everything here installs from the `nixpkgs` flake instead.
RUN curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon --no-channel-add \
    && nix profile add --impure \
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
    # C compiler
    nixpkgs#gcc \
    # tree-sitter CLI: generate / test / build a grammar by hand (nvim-treesitter's install dir is the read-only
    # nix one, so :TSInstall can't add parsers; add them via nix instead)
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
    # modern replacements: grep, find, cat, ls, sed (find & replace), curl (HTTP client)
    nixpkgs#ripgrep \
    # nixpkgs#ripgrep-all \
    nixpkgs#fd \
    nixpkgs#bat \
    nixpkgs#eza \
    nixpkgs#sd \
    nixpkgs#xh \
    # fuzzy finder
    nixpkgs#fzf \
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
    # structured data: query json (jq, and jaq: a faster jq clone), turn command output into json, make json
    # greppable, query yaml
    nixpkgs#jq \
    nixpkgs#jaq \
    nixpkgs#jc \
    nixpkgs#gron \
    nixpkgs#yq-go \
    # json viewer (collapsible tree); csv toolkit (select, stats, join, ...) and viewer
    nixpkgs#jless \
    nixpkgs#qsv \
    nixpkgs#csvlens \
    # convert hcl2 (nomad, terraform) to json so it's easier for claude to read
    nixpkgs#hcl2json \
    # simple statistics (mean, stddev, ...) from numbers on stdin
    nixpkgs#sta \
    # convert between markup formats (markdown, html, docx, ...)
    nixpkgs#pandoc \
    # code search, diffs & stats
    # search and rewrite code using its ast
    nixpkgs#ast-grep \
    # diff viewers: pager for git output, and structural diff that understands syntax
    nixpkgs#delta \
    nixpkgs#difftastic \
    # git merge driver that resolves conflicts using the syntax tree (set up in home/.config/git)
    nixpkgs#mergiraf \
    # count lines of code
    nixpkgs#tokei \
    # language servers, linters & formatters
    # language servers (for neovim)
    nixpkgs#ty \
    nixpkgs#bash-language-server \
    nixpkgs#yaml-language-server \
    nixpkgs#vim-language-server \
    nixpkgs#dockerfile-language-server \
    # lua (rust rewrite of the EmmyLua server)
    nixpkgs#emmylua-ls \
    nixpkgs#jinja-lsp \
    # html, css, json (its eslint server is not used: biome lints js/ts)
    nixpkgs#vscode-langservers-extracted \
    # json, css, js/ts, html, graphql: lint + format
    nixpkgs#biome \
    # toml: lint + format (with schemastore schemas, e.g. pyproject.toml)
    nixpkgs#tombi \
    # grammar and spelling in prose and comments (harper-ls)
    nixpkgs#harper \
    # file watcher backend for nvim's LSP client (:checkhealth vim.lsp: libuv's is slow on big trees)
    nixpkgs#inotify-tools \
    # nixpkgs#nodePackages.neovim \
    # python: lint/format, and find unused functions/variables/...
    nixpkgs#ruff \
    nixpkgs#python314Packages.vulture \
    # shell: lint and format
    nixpkgs#shellcheck \
    nixpkgs#shfmt \
    # lua: format
    nixpkgs#stylua \
    # yaml, markdown (lint + format, also a language server), ansible
    nixpkgs#yamllint \
    nixpkgs#rumdl \
    # NOTE: ansible-lint is 585MiB
    #nixpkgs#ansible-lint \
    # jinja2 templates: djlint (lint + format, HTML templates), j2lint (lint), jinja2-cli (render a template)
    nixpkgs#djlint \
    nixpkgs#j2lint \
    nixpkgs#jinja2-cli \
    # sql: lint and auto-format
    nixpkgs#sqruff \
    # dockerfiles
    nixpkgs#hadolint \
    # terraform .tf files: lint, and a language server (completion, hover; formatting needs the terraform CLI)
    nixpkgs#tflint \
    nixpkgs#terraform-ls \
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
    # report on credential leaks: gitleaks git -v (thorough), ripsecrets (fast, for pre-commit)
    nixpkgs#gitleaks \
    nixpkgs#ripsecrets \
    # debugging, profiling & monitoring
    # system inspection: processes, open files, network (netstat, ifconfig)
    nixpkgs#htop \
    nixpkgs#lsof \
    nixpkgs#net-tools \
    # log file viewer
    nixpkgs#lnav \
    # python sampling profiler, syscall tracer, debugger
    #nixpkgs#py-spy \ # takes 1000+ seconds to build, use binary build from elsewhere
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
    # CLI only (talks to a mounted host socket); the full nixpkgs#docker adds dockerd/containerd/moby (~330 MiB).
    # docker-client already wraps the buildx and compose plugins (`docker compose`); docker-compose adds the standalone
    # `docker-compose` command (same store path, so no extra size)
    nixpkgs#docker-client \
    nixpkgs#docker-compose \
    nixpkgs#kubectl \
    nixpkgs#kustomize \
    # explore docker image layers and find wasted space
    nixpkgs#dive \
    # NOTE: may want to skip as these take time to build and are likely not needed
    # nixpkgs#nomad \
    # nixpkgs#terraform \
    # nixpkgs#plantuml \
    # python
    # fast pip/venv replacement (micromamba is installed separately below)
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
    #
    # NEOVIM (wrapped with nvim-treesitter + all grammars/queries from nixpkgs)
    # `withAllGrammars` pulls in its parsers and queries only via a wrapped neovim, so install neovim that way.
    # wrapRc = false: keep loading ~/.config/nvim/init.lua instead of a generated init.
    && nix profile add --impure --expr \
    'let p = (builtins.getFlake "nixpkgs").legacyPackages.${builtins.currentSystem}; \
    in p.wrapNeovimUnstable p.neovim-unwrapped { \
    plugins = [ p.vimPlugins.nvim-treesitter.withAllGrammars ]; \
    wrapRc = false; \
    }' \
    #
    # MICROMAMBA (env manager, envs live in $MAMBA_ROOT_PREFIX)
    # nixpkgs#micromamba is a wrapper script that execs mamba-cpp's binary as `.mamba-wrapped`, and micromamba refuses to
    # `run`/`activate` unless its own filename is `micromamba` or `mamba`, so install that binary under the right name.
    # (The wrapper only set defaults for MAMBA_ROOT_PREFIX/CONDA_PKGS_DIRS/CONDA_ENVS_PATH, which are set below anyway.)
    && nix profile add --impure --expr \
    'let p = (builtins.getFlake "nixpkgs").legacyPackages.${builtins.currentSystem}; \
    in p.runCommand "micromamba-${p.mamba-cpp.version}" { } \
    "mkdir -p $out/bin && cp ${p.mamba-cpp}/bin/.mamba-wrapped $out/bin/micromamba"' \
    #
    # CLEANUP (only shrinks the image if chained onto the same RUN as the installs)
    # gc: drop build-only deps (e.g. vim/ruby for the custom neovim wrapper, which isn't in the binary cache).
    # No `nix store optimise` needed, as auto-optimise-store dedups as paths are added.
    # ~/.cache/nix: the downloaded nixpkgs source and eval cache (~80 MiB), only needed while evaluating.
    && nix store gc \
    && rm -rf "${HOME}/.cache/nix"

## CONFIG FILES
COPY --chown=${UID}:${GID} ["home", "${HOME}/"]
COPY --chown=${UID}:${GID} ["sandbox/conda", "/sandbox/${USER}/conda"]
RUN mkdir -p "/sandbox/${USER}/repos"

## GNUPG (XDG_DATA_HOME instead of ~/.gnupg)
ENV GNUPGHOME="${HOME}/.local/share/gnupg"
RUN chmod 700 "${GNUPGHOME}"

## BAT THEME (register the custom selenized-light theme from home/.config/bat/themes)
RUN bat cache --build

## NVIM SETUP
# Plugins are managed by neovim's built-in vim.pack (see home/.config/nvim/lua/config/plugins.lua). The first headless
# start installs the latest upstream version of each (no lockfile is shipped); the second fails the build if the config errors.
RUN echo "Installing nvim plugins using vim.pack:" \
    && nvim --headless -c 'qa' \
    && echo "Checking the nvim config loads cleanly:" \
    && nvim --headless -c 'if v:errmsg != "" | echo v:errmsg | cquit 1 | endif' -c 'qa'

## ZSH
ENV ZDOTDIR="${HOME}/.config/zsh"

## PYTHON
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTEST_ADDOPTS="-p no:cacheprovider"

## MICROMAMBA
ENV MAMBA_ROOT_PREFIX="/sandbox/${USER}/conda" \
    CONDA_ENVS_PATH="/sandbox/${USER}/conda/envs" \
    CONDA_PKGS_DIRS="/sandbox/${USER}/conda/pkgs" \
    CONDARC="/sandbox/${USER}/conda/.condarc"

RUN mkdir -p "${HOME}/.cache/mamba/proc" "${CONDA_ENVS_PATH}" "${CONDA_PKGS_DIRS}"

## UV
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

RUN mkdir -p "${UV_PROJECT_ENVIRONMENT}" "${UV_PYTHON_INSTALL_DIR}" "${UV_TOOL_BIN_DIR}" "${UV_TOOLS_DIR}"

## Claude (use XDG_CONFIG_HOME)
ENV CLAUDE_CONFIG_DIR="${HOME}/.config/claude"

## MAN & COMPLETION (UPDATE DBS AFTER ALL THE ABOVE INSTALLS)
RUN sudo mandb --create

# CMD: tini as PID 1: `sleep` alone ignores SIGTERM (so stopping waits for the kill timeout) and never reaps orphaned processes
ENTRYPOINT ["tini", "--"]
CMD ["sleep", "infinity"]
