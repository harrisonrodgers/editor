FROM ubuntu:22.04

## MICROMAMBA ##########################################################################################################
ENV MAMBA_ROOT_PREFIX="/opt/conda"

# Set environment variables that micromamba init would normally set
ENV PATH="${MAMBA_ROOT_PREFIX}/condabin:${PATH}" \
    MAMBA_EXE="/bin/micromamba" \
    CONDA_SHLVL="0"

# Install
RUN apt-get update \
    && apt-get -y install curl tzdata bzip2 \
    && dpkg-reconfigure -f noninteractive tzdata \
    # Install Miniconda
    && curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/1.5.8 | tar -xj -C /tmp bin/micromamba \
    && mv /tmp/bin/micromamba ${MAMBA_EXE} \
    && rmdir /tmp/bin \
    # Run init (commented out as I have this included in my .zshrc already)
    # micromamba shell init --shell bash --root-prefix=${MAMBA_ROOT_PREFIX} \
    # Information
    && micromamba info \
    # Give other users ability to use conda
    && mkdir ${MAMBA_ROOT_PREFIX} \
    && chmod -R a+rwX ${MAMBA_ROOT_PREFIX} --changes \
    # Remove packages to reduce image bloat
    && apt-get -y remove curl bzip2 \
    # && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log
    # System level conda configuration
    # && echo "changeps1: False" > ${MAMBA_ROOT_PREFIX}/.condarc

# Activate the base env by default
ENV PATH="${MAMBA_ROOT_PREFIX}/bin:${PATH}" \
    CONDA_DEFAULT_ENV="base" \
    CONDA_PREFIX="${MAMBA_ROOT_PREFIX}" \
    CONDA_PROMPT_MODIFIER="(base)" \
    CONDA_SHLVL="1"

## TERM (matters to apps like ZSH/TMUX/...) ############################################################################
ENV TERM=xterm-256color

## LANG ################################################################################################################
ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

## UNMINIMIZE UBUNTU ###################################################################################################
RUN yes | unminimize


## DOCKER IN DOCKER ####################################################################################################

## INSTALL #############################################################################################################
RUN apt-get update \
    && apt-get -y install sudo build-essential openssh-client man-db git-man manpages manpages-dev manpages-posix manpages-posix-dev plantuml tzdata curl ncurses-term \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log

## USER SETUP ##########################################################################################################
ENV USER=harrison.rodgers \
    GROUP=harrison.rodgers \
    UID=501211 \
    GID=1001
ENV HOME=/home/$USER
ENV PATH=$HOME/.bin:$PATH
RUN groupadd -g $GID $GROUP \
    && useradd -u $UID -g $GID -d $HOME -s /bin/sh $USER --create-home -k /dev/null \
    # password-less sudo inside the container
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

## USER ACTIVATE FOR REST OF DOCKERFILE (note: after this point, need to use sudo) #####################################
USER $UID:$GID
WORKDIR $HOME

## INSTALL NIX #########################################################################################################
ENV PATH=$HOME/.nix-profile/bin:$PATH \
    NIXPKGS_ALLOW_UNFREE=1
RUN curl -L https://nixos.org/nix/install | sh \
    && nix-channel --update

## INSTALL PACKAGES ####################################################################################################
RUN nix-env -iA \
# reference
    # nixpkgs.man \
    # nixpkgs.manpages \
    # nixpkgs.stdman \
    # nixpkgs.llvm-manpages \
    # nixpkgs.clang-manpages \
    # nixpkgs.man-pages \
    # nixpkgs.posix_man_pages \
# shell
    nixpkgs.zsh \
    nixpkgs.zsh-fzf-tab \
    nixpkgs.zsh-syntax-highlighting \
# prompt
    nixpkgs.starship \
    # nixpkgs.zsh-powerlevel10k # consider, faster, though zsh only
# container
    nixpkgs.docker \
# multiplexer
    nixpkgs.tmux \
# python (using micromamba instead)
    # nixpkgs.python310Full \
# editor (using appimage instead)
    # nixpkgs.neovim  \
    nixpkgs.nano \
# backup 
    nixpkgs.nano \ 
# misc
    nixpkgs.git \
    nixpkgs.direnv \
    nixpkgs.fzf \
    nixpkgs.ripgrep \
    # nixpkgs.ripgrep-all \
    nixpkgs.fd \
    nixpkgs.tree \
    nixpkgs.bat \
    nixpkgs.eza \
    nixpkgs.lnav \
    nixpkgs.sta \
    nixpkgs.gawk \
    nixpkgs.less \
    nixpkgs.zoxide \
    nixpkgs.kubectl \
    nixpkgs.renameutils \
# to complie nvim tree-sitter parsers
    nixpkgs.gcc \
# neovim, lsp, formatters, linters
    # note: most python formatter/linter are managed in the app's conda env
    # nixpkgs.ruff \
    nixpkgs.ruff-lsp \
    nixpkgs.nodePackages.neovim \
    nixpkgs.pyright \
    nixpkgs.yaml-language-server \
    nixpkgs.vim-language-server \
    nixpkgs.nodePackages.bash-language-server \
    nixpkgs.dockerfile-language-server-nodejs \
    nixpkgs.vscode-langservers-extracted \
    nixpkgs.stylua \
    nixpkgs.gitlint \
    nixpkgs.yamllint \
    nixpkgs.luajitPackages.luacheck \
# misc dev 
    nixpkgs.kustomize \
    nixpkgs.plantuml \
# cleanup
    # && nix-env -u \
    && nix-env --delete-generations old \
    && nix-store --gc \
    && nix-store --optimize \
    && nix-store --verify --check-contents

## REMOVE python if it snuck in (as we use micromamba) #################################################################
RUN sudo apt-get remove -y python3 \
    && sudo apt-get -y autoremove

## MAN & COMPLETION (UPDATE DBS AFTER ALL THE ABOVE INSTALLS) ##########################################################
RUN sudo mandb --create

## CONFIG FILES ########################################################################################################
COPY --chown=$UID:$GID ["home", "${HOME}/"]

## NVIM INSTALL ########################################################################################################
RUN mkdir -p $HOME/.bin \
    && curl -L -o /tmp/nvim.appimage https://github.com/neovim/neovim/releases/download/v0.10.2/nvim.appimage \
    && chmod u+x /tmp/nvim.appimage \
    && /tmp/nvim.appimage --appimage-extract \
    && rm /tmp/nvim.appimage \
    && mv squashfs-root $HOME/.bin \
    && ln -s $HOME/.bin/squashfs-root/usr/bin/nvim $HOME/.bin/nvim

## NVIM SETUP ##########################################################################################################
RUN mkdir -p $HOME/.local/share/nvim/site/autoload \
    # paq-nvim install
    && echo "Installing paq-nvim:" \
    && git clone --depth=1 https://github.com/savq/paq-nvim.git $HOME/.local/share/nvim/site/pack/paqs/start/paq-nvim \
    && echo "Installing nvim packages using paq-nvim:" \
    && nvim --headless -u NONE -c 'lua require("config/bootstrap").bootstrap_paq()' \
    && echo "" \
    # treesitter install (sync is slow, but safest way to do it automated)
    && echo "Installing nvim-treesitter language parsers:" \
    && nvim --headless -c "TSInstallSync all" -c "qa"

## ZSH #################################################################################################################
ENV ZDOTDIR=$HOME/.config/zsh

## PYTHON ##############################################################################################################
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTEST_ADDOPTS="-p no:cacheprovider"

## CMD #################################################################################################################
CMD ["tmux","-S","/tmp/tmux.sock"]
