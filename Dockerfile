FROM ubuntu:18.04

## CONDA ###############################################################################################################
ENV CONDA_ROOT="/opt/conda"

# Set environment variables that conda init would normally set
ENV PATH="${CONDA_ROOT}/bin:${CONDA_ROOT}/condabin:${PATH}" \
    CONDA_DEFAULT_ENV="base" \
    CONDA_EXE="${CONDA_ROOT}/bin/conda" \
    CONDA_PREFIX="${CONDA_ROOT}" \
    CONDA_PROMPT_MODIFIER="(base)" \
    CONDA_PYTHON_EXE="${CONDA_ROOT}/bin/python" \
    CONDA_SHLVL="1" \
    _CE_CONDA="" \
    _CE_M=""

# Install conda
RUN apt-get update \
    && apt-get -y install curl tzdata \
    && apt-mark manual curl tzdata \
    && dpkg-reconfigure -f noninteractive tzdata \
    # Fetch Miniconda install script
    && curl -SsLo /tmp/miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-py38_4.9.2-Linux-x86_64.sh \
    # Install Miniconda
    && bash /tmp/miniconda.sh -bfp $CONDA_ROOT \
    # Cleanup Miniconda install script
    && rm -rf /tmp/miniconda.sh \
    && conda config --show \
    # Clean conda to reduce image bloat
    && conda clean --all --yes \
    # Give other users ability to use conda
    && mkdir /.conda \
    && chmod 777 /.conda \
    # Remove packages to reduce image bloat
    && apt-get -y remove curl \
    && apt-get -y autoremove \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log \
    # System level conda configuration
    && echo "changeps1: False" > ${CONDA_ROOT}/.condarc

## TERM (matters to apps like ZSH/TMUX/...) ############################################################################
ENV TERM=xterm-256color

## LANG ################################################################################################################
ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

## UNMINIMIZE UBUNTU ###################################################################################################
RUN yes | unminimize

## DOCKER IN DOCKER ####################################################################################################
RUN apt-get update \
    && apt-get -y install docker.io \
    && mkdir /.docker \
    && chmod 777 /.docker \
    && apt-get -y autoremove \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log

## INSTALL DEPS FOR SUBSEQUENT STEPS ###################################################################################
RUN apt-get update \
    && apt-get -y install sudo build-essential openssh-client man-db git-man git manpages manpages-dev manpages-posix manpages-posix-dev plantuml tzdata curl ncurses-term gcc libncurses5-dev \
    && apt-get -y autoremove \
    && apt-get -y install plantuml \
    && apt-get autoclean \
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

## USER ACTIVATE FOR REST OF DOCKERFILE ################################################################################
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
# prompt
    nixpkgs.starship \
# multiplexer
    nixpkgs.tmux \
# python
    # nixpkgs.python310Full \
# editor
    # nixpkgs.neovim  \
# misc
    # nixpkgs.git \
    nixpkgs.direnv \
    nixpkgs.fzf \
    nixpkgs.ripgrep \
    # nixpkgs.ripgrep-all \
    nixpkgs.fd \
    nixpkgs.tree \
    nixpkgs.bat \
    nixpkgs.exa \
    nixpkgs.lnav \
    nixpkgs.gawk \
    nixpkgs.less \
    nixpkgs.zoxide \
    nixpkgs.kubectl \
    nixpkgs.renameutils \
# to complie nvim tree-sitter parsers
    # nixpkgs.gcc \
# neovim, lsp, formatters, linters
    nixpkgs.nodePackages.neovim \
    nixpkgs.nodePackages.pyright \
    nixpkgs.nodePackages.yaml-language-server \
    nixpkgs.nodePackages.vim-language-server \
    nixpkgs.nodePackages.bash-language-server \
    nixpkgs.nodePackages.dockerfile-language-server-nodejs \
    nixpkgs.nodePackages.vscode-langservers-extracted \
    nixpkgs.stylua \
    nixpkgs.gitlint \
    nixpkgs.luajitPackages.luacheck \
# kustomize
    nixpkgs.kustomize \
# cleanup
    # && nix-env -u \
    && nix-env --delete-generations old \
    && nix-store --gc \
    && nix-store --optimize \
    && nix-store --verify --check-contents

## CONFIG FILES ########################################################################################################
COPY --chown=$UID:$GID ["home", "${HOME}/"]

## NVIM INSTALL ########################################################################################################
RUN mkdir -p $HOME/.bin \
    && curl -L -o /tmp/nvim.appimage https://github.com/neovim/neovim/releases/download/v0.8.1/nvim.appimage \
    && chmod u+x /tmp/nvim.appimage \
    && /tmp/nvim.appimage --appimage-extract \
    && rm /tmp/nvim.appimage \
    && mv squashfs-root $HOME/.bin \
    && ln -s $HOME/.bin/squashfs-root/usr/bin/nvim $HOME/.bin/nvim

## NVIM SETUP ##########################################################################################################
RUN mkdir -p $HOME/.local/share/nvim/site/autoload \
    # vim-plug install
    #&& curl -o $HOME/.local/share/nvim/site/autoload/plug.vim https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
    #&& nvim --headless -u "${HOME}/.config/nvim/plug.vim" -c "PlugInstall" -c "qa" \
    # paq0nvim install
    && echo "Installing paq-nvim:" \
    && git clone --depth=1 https://github.com/savq/paq-nvim.git $HOME/.local/share/nvim/site/pack/paqs/start/paq-nvim \
    && echo "Installing nvim packages using paq-nvim:" \
    && nvim --headless -u NONE -c 'lua require("config/bootstrap").bootstrap_paq()' \
    && echo "" \
    # treesitter install
    && echo "Installing nvim-treesitter language parsers:" \
    && nvim --headless -c "TSInstallSync all" -c "qa"
# treesitter install sync is slow; it's possible to do it async but dangerous as we have to sleep for long enough time
#   && nvim --headless -c "execute 'TSInstall all' | sleep 30 | qa"

## REMOVE ##############################################################################################################
RUN sudo apt-get remove -y python3 python3.6 python3.6-minimal

## MAN & COMPLETION (UPDATE DBS AFTER ALL THE ABOVE INSTALLS) ##########################################################
RUN sudo mandb --create

## ZSH #################################################################################################################
ENV ZDOTDIR=$HOME/.config/zsh \
    ZPLUG_HOME=/home/harrison.rodgers/.config/zsh/zplug
RUN git clone https://github.com/zplug/zplug $HOME/.config/zsh/zplug

# Trigger zplug to install everything so we don't have to do it each container launch
RUN zsh -c "source ~/.config/zsh/.zshrc && exit"

# Build fzf-tab binary module to speed up performance (requires libncurses5-dev)
RUN zsh -c "source ~/.config/zsh/.zshrc && build-fzf-tab-module && exit"

## PYTHON ##############################################################################################################
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTEST_ADDOPTS="-p no:cacheprovider"

## CMD #################################################################################################################
CMD ["tmux","-S","/tmp/tmux.sock"]
