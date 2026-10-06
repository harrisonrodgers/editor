# editor

Containerized development environment: build the image once, then start it fresh, with no accumulated state, cache or junk.

## Use

```sh
_build/container_build_with_cache.sh   # build (docker_build_*.sh for docker); image tag: ${USER}-editor:<date>
echo 'CLAUDE_CODE_OAUTH_TOKEN=...' > env   # gitignored
./run-container-simple.sh              # start (or attach to) the container, tmux session 0, this dir mounted at /host
```

Set `VERSION` in `run-container-simple.sh` to the build date. `claude` is installed at container start (`nix profile add github:sadjow/claude-code-nix`).

## Layout

| path                      | what                                                                   |
|---------------------------|------------------------------------------------------------------------|
| `Dockerfile`              | ubuntu + nix; packages: interactive tools, then dev tooling (LSPs, linters); neovim wrapped with all treesitter grammars |
| `home/`                   | copied into `$HOME` (zsh, tmux, nvim, bat, starship, ruff, typos, ...) |
| `_build/`                 | build scripts (`container` and `docker`, with and without cache)       |
| `run-container-simple.sh` | run / attach                                                           |
| `env`                     | secrets for the container, never committed                             |

## Tools

| area           | selection                | link                                       |
|----------------|--------------------------|--------------------------------------------|
| shell          | `zsh` + `fzf-tab`, syntax highlighting | <http://zsh.sourceforge.net> |
| prompt         | `starship`               | <https://github.com/starship/starship>     |
| multiplexer    | `tmux`                   | <https://github.com/tmux/tmux>             |
| fuzzy finder   | `fzf`                    | <https://github.com/junegunn/fzf>          |
| cat / grep / ls / find | `bat` / `ripgrep` / `eza` / `fd` | <https://github.com/sharkdp/bat> |
| packages       | `nix`                    | <https://github.com/nixos/nix>             |
| python envs    | `micromamba` (`/sandbox/$USER/conda`), `uv` | <https://github.com/mamba-org/mamba> |
| colorscheme    | selenized (light)        | <https://github.com/jan-warchol/selenized> |

## nvim

`neovim` 0.12, config in `home/.config/nvim/lua/config/`. Keys: shown on the start screen (`start_screen.lua`).

**plugins** (`vim.pack`, `plugins.lua`; `:lua vim.pack.update()`; no lockfile shipped, each build takes the latest)

| plugin               | for                                              |
|----------------------|--------------------------------------------------|
| `selenized.nvim`     | colorscheme                                      |
| `nvim-lspconfig`     | language server definitions                      |
| `lsp_signature.nvim` | signature help popup while typing a call        |
| `nvim-lint`          | linters without an LSP                           |
| `conform.nvim`       | formatters / fixers                              |
| `telescope.nvim` (+ `plenary.nvim`) | pickers: files, grep, LSP, diagnostics |
| `gitsigns.nvim`      | git gutter, blame                                |
| `hlchunk.nvim`       | line number highlight for the current chunk      |
| `render-markdown.nvim` | markdown rendering (`latex2text` for math)     |
| `nvim-rooter.lua`    | cwd to project root                              |

Built in, no plugin: completion (`autocomplete` + `vim.lsp.completion`), inlay hints, folding, linked editing, `:Undotree`, `:DiffTool`. Treesitter parsers come from nix.

**lsp** (`lsp.lua`)

| server | for |
| -------- | ----- |
| `ty` | python types, hints |
| `ruff` | python lint, format |
| `typos-lsp` | spelling (`~/.config/typos/typos.toml`) |
| `lua/bash/yaml/vim/docker-language-server` | lua, bash, yaml, vim, dockerfile |
| `vscode-langservers-extracted` | json, css, html, eslint |

**lint / format** (`lint_format.lua`)

- lint: `markdownlint-cli2`, `yamllint`, `hadolint`, `tflint`, `sqlfluff`, `buf`, `gitlint`, `xmllint` (custom)
- format: `stylua`, `shfmt`, `markdownlint-cli2`, `buf`, `sqlfluff`, `xmllint`; python by `ruff`
- python on save: `ruff_fix` (repo config only) then the ruff LSP formats. Extra rules (`RET`, `TID252`) show in nvim only, never auto-fixed.
- user ruff config (`~/.config/ruff/ruff.toml`) only applies in repos without their own.
