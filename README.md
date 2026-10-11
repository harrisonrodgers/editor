# Editor

Containerized development environment: build the image once, then start it fresh, with no accumulated state, cache, or junk.

## How to Build

Needs Apple's [`container`](https://github.com/apple/container) or Docker. Run the scripts from the repo root.

```sh
editor $ _build/container_build_with_cache.sh   # or _build/container_build_no_cache.sh
editor $ _build/docker_build_with_cache.sh      # or _build/docker_build_no_cache.sh
```

- The image is tagged `${USER}-editor:<YYYY-MM-DD>` (the build date). Every build pulls the latest `ubuntu:22.04`.
- The build installs ubuntu base packages, then nix and every tool from `nixpkgs` (see the `PACKAGES` section of the
  `Dockerfile`). It installs neovim with all treesitter grammars, copies `home/` into `$HOME`, installs the nvim plugins
  (latest upstream, no lockfile), and fails if the nvim config doesn't load cleanly.
- The user is hard-coded in the `Dockerfile` (`USER`, `UID`, `GID`); change them to build for someone else.

## How to Run

```sh
./run-container.sh   # Apple container
./run-docker.sh      # Docker
```

Run it from the repo root: the repo is mounted at `/host` and `env` is read from the current directory.

- If the container (`${USER}-editor`) is already running, the script attaches to it. Otherwise it starts a new one,
  then attaches to tmux session `0` (created if missing), so running the script again opens the same session.
- On start, the container sets the git user name and email (hard-coded in the run scripts) and installs the latest
  `claude` (`nix profile add nixpkgs#claude-code`).
- The scripts run the image tagged with **today's** date. To run an image built on an earlier day, rebuild, or set
  `VERSION` in the run script to the build date.
- Detaching from tmux leaves the container running. Stop it with `container stop ${USER}-editor` or
  `docker stop ${USER}-editor`. It is started with `--rm`, so stopping deletes it: only `/host` survives.
- The container gets `SYS_PTRACE` (for `gdb`, `strace`, `py-spy`). Docker also runs it with seccomp, apparmor and
  systempaths unconfined.

## Inside Container

### Directories

| path                     | what                                                                                 |
|--------------------------|--------------------------------------------------------------------------------------|
| `/home/${USER}`          | `$HOME`, from `home/` (zsh, tmux, nvim, git, bat, starship, ruff, typos, ...)        |
| `/sandbox/${USER}`       | working directory on start                                                           |
| `/sandbox/${USER}/repos` | for cloning repos into (empty, not persisted)                                        |
| `/sandbox/${USER}/conda` | micromamba root: `envs/`, `pkgs/`, `.condarc` (conda-forge, then defaults)           |
| `/sandbox/${USER}/uv`    | uv: `venv/` (project env), `python/` (interpreters), `tools/`, `tool_bin/` (on PATH) |

Nothing is kept as a dotfile directly in `$HOME`: configs are in `~/.config`, data in `~/.local/share`, state and
history in `~/.local/state`, caches in `~/.cache` (the `XDG_*` dirs). That includes nix (its profile, with every
nixpkgs tool, is `~/.local/state/nix/profile`: `use-xdg-base-directories` in `/etc/nix/nix.conf`), Claude Code
(`~/.config/claude`) and gpg (`~/.local/share/gnupg`).

### Environment Variables

Set in the `Dockerfile`:

| variable                                                   | value / purpose                                    |
|------------------------------------------------------------|----------------------------------------------------|
| `TERM`, `COLORTERM`                                        | `xterm-256color`, `truecolor`                      |
| `LANG`, `LC_ALL`                                           | `C.UTF-8`                                          |
| `PATH`                                                     | adds `~/.local/state/nix/profile/bin` (nix) and    |
|                                                            | uv's `tool_bin`                                    |
| `NIXPKGS_ALLOW_UNFREE`                                     | `1`                                                |
| `ZDOTDIR`                                                  | `~/.config/zsh` (zsh config location)              |
| `GNUPGHOME`                                                | `~/.local/share/gnupg` (instead of `~/.gnupg`)     |
| `CLAUDE_CONFIG_DIR`                                        | `~/.config/claude` (instead of `~/.claude` and     |
|                                                            | `~/.claude.json`)                                  |
| `PYTHONDONTWRITEBYTECODE`, `PYTEST_ADDOPTS`                | no `.pyc` files, no `.pytest_cache`                |
| `MAMBA_ROOT_PREFIX`, `CONDA_ENVS_PATH`, `CONDA_PKGS_DIRS`  | `/sandbox/${USER}/conda`, its `envs/` and `pkgs/`  |
| `UV_PROJECT_ENVIRONMENT`                                   | `/sandbox/${USER}/uv/venv`, shared by all projects |
| `UV_PYTHON_INSTALL_DIR`, `UV_TOOLS_DIR`, `UV_TOOL_BIN_DIR` | under `/sandbox/${USER}/uv`                        |
| `UV_NO_CACHE`, `UV_COMPILE_BYTECODE`, `UV_NO_DEV`          | `1`: no cache, compile on install, skip dev deps   |

From `env` at run time: `CLAUDE_CODE_OAUTH_TOKEN`. From `~/.config/zsh/.zshrc` (Claude Code's shell gets these too):
`EDITOR`/`VISUAL` (`nvim`), the `XDG_*` dirs, with caches, histories and configs moved into them instead of `~` or the
project (python, ruff, mypy, less, sqlite, zsh, rumdl `RUMDL_CACHE_DIR`, ansible `ANSIBLE_HOME`, wget `WGETRC`,
readline `INPUTRC`), plus the `fzf`, `less`, `starship` and `direnv` setup. direnv trusts
every `.envrc` under `/sandbox/${USER}/repos` (`~/.config/direnv/config.toml`); elsewhere it asks for `direnv allow`.

### Clipboard

The container has no access to the host OS clipboard, so copying goes through the terminal instead: tmux has
`set-clipboard on` (`~/.config/tmux/tmux.conf`), which sends whatever is copied in tmux on to the outer terminal as an
OSC 52 escape sequence, and the terminal puts it on the host OS clipboard. This needs a terminal with OSC 52 support
(e.g. iTerm2, Ghostty, kitty, WezTerm, Windows Terminal; not macOS's Terminal.app) and only works inside tmux.

| what                    | copies to the host OS clipboard                                                         |
|-------------------------|-----------------------------------------------------------------------------------------|
| tmux copy mode          | the selection                                                                           |
| nvim `"+y` / `"*y`      | the yank (nvim's clipboard provider is tmux: `tmux load-buffer -w`)                     |
| nvim `gx`, `xdg-open`   | the URL / path, instead of opening it (no browser here): `~/.local/bin/xdg-open`        |

Pasting from the host OS clipboard: use the terminal's paste (Cmd+V / Ctrl+Shift+V). nvim's `"+p` asks the terminal
for its clipboard (`tmux refresh-client -l`), which many terminals block or ask permission for.

### Claude Code

`claude` is installed at container start. Its config dir is `~/.config/claude` (`CLAUDE_CONFIG_DIR`), from
`home/.config/claude`:

- `.claude.json`: skips onboarding.
- `settings.json`: the `opus` model, light theme, a quiet spinner (no tips, just "Processing"), no away summary or turn
  duration, no automatic model switch when safeguards flag a message, Ctrl+G's external editor starts with the last
  response, no attribution or session link in commits and PRs, no error reporting or telemetry, and the sandboxed
  shell may also read and write `/sandbox/${USER}/{conda,uv,repos}` and `~/.cache`.
- `CLAUDE.md`: which CLI tools are installed, that `python3` isn't on PATH (use the active micromamba env's `python`,
  else `uv run python`), and that git merges go through mergiraf.

Use `claude setup-token` to get a one-year token to mount into the container:

```sh
echo 'CLAUDE_CODE_OAUTH_TOKEN=...' > env
```

## Nvim

`neovim` from nixpkgs (0.12 features are used), config in `home/.config/nvim/` (`init.lua`, `lua/config/*.lua`). The
keys are shown on the start screen.

### Handmade

Implemented in this configuration, in Lua.

| handmade                     | for                                                   | where              |
|------------------------------|-------------------------------------------------------|--------------------|
| start screen                 | key cheat sheet when nvim starts without a file       | `start_screen.lua` |
| completion item display      | kind colors, `[server] detail`, cut-short long items  | `lsp.lua`          |
| completion docs popup border | same rounded border as the completion menu            | `lsp.lua`          |
| completion keys              | `<Tab>`/`<S-Tab>` menu or snippet, `<CR>` if selected | `lsp.lua`          |
| LSP lookups in telescope     | `gd`, `grr`, `gri`, `grt`, `gO`, `grs`, `grc`, `grC`  | `lsp.lua`          |
| symbol highlight             | the symbol under the cursor and its uses              | `init.lua`         |
| diagnostic format            | `[source] (code) message`, `E`/`W`/`I`/`H` prefix     | `diagnostic.lua`   |
| diagnostics picker           | `<C-w>D` this buffer, `<space>Q` all open buffers     | `diagnostic.lua`   |
| linewise visual highlight    | `V` highlights the selected lines to the window edge  | `init.lua`         |
| quickfix height              | quickfix / location lists shrink to fit (max 10)      | `init.lua`         |
| cursor restore               | reopening a file puts the cursor where it was (not in | `init.lua`         |
|                              | git commit / rebase messages)                         |                    |
| reload on change             | reload a buffer when its file changes on disk         | `init.lua`         |
| linters                      | `xmllint`, `j2lint`, `tflint`; `gitlint` reads the    | `lint_format.lua`  |
|                              | buffer (not the saved file) and the user config       |                    |
| git gutter                   | blank colored signs, fainter once staged; hunk keys   | `gitsigns.lua`     |
|                              | (`]h` `[h` `<space>h{p,s,r,d}`), `gb` blame           |                    |
| sqruff user config           | used where a project has none: nvim roots the server  | `lsp.lua`,         |
|                              | in `~/.config/sqruff`; zsh's `sqruff` adds `--config` | `.zshrc`           |
| theme tweaks                 | cursor line, selection, inlay hint, border colors     | `colorscheme.lua`  |
| `tint()`                     | blend two colors, for tinted highlights               | `tint.lua`         |

### Builtin

Part of Neovim, no plugin needed.

| builtin                                   | for                                                        |
|-------------------------------------------|------------------------------------------------------------|
| `vim.pack`                                | plugin manager (`plugins.lua`)                             |
| `nvim.undotree` (`:Undotree`)             | visual undo tree (`packadd` in `init.lua`)                 |
| `nvim.difftool` (`:DiffTool`)             | compare two files or directories (`packadd` in `init.lua`) |
| `vim.lsp.config` / `vim.lsp.enable`       | language server setup (`lsp.lua`)                          |
| `autocomplete` + `vim.lsp.completion`     | completion menu while typing                               |
| `wildtrigger()` + `wildoptions=pum,fuzzy` | completion menu on the `:`, `/` and `?` command line       |
| `vim.snippet`                             | jump between snippet fields with `<Tab>`                   |
| `vim.lsp.inlay_hint`                      | inlay hints (types, parameter names)                       |
| `vim.lsp.foldexpr`                        | folding from the language server                           |
| `vim.lsp.linked_editing_range`            | editing an html tag also edits its closing tag             |
| `vim.lsp.codelens`                        | code lens above lines                                      |
| `vim.lsp.inline_completion`               | ghost-text completion, accepted with `<C-l>`               |
| `vim.lsp.buf.document_highlight`          | highlight the symbol under the cursor and its uses         |
| `vim.lsp.buf.typehierarchy`               | subtypes / supertypes (`grh` / `grH`)                      |
| `vim.diagnostic`                          | diagnostics display (`diagnostic.lua`)                     |
| `vim.treesitter`                          | syntax highlighting (parsers: see Treesitter)              |
| `undofile`, `backup`                      | persistent undo history, backup before overwriting (both   |
|                                           | in `~/.local/state/nvim`)                                  |

### Plugins

Managed by `vim.pack` (`plugins.lua`), updated with `:lua vim.pack.update()`. No lockfile is shipped (a live
`nvim-pack-lock.json` is in `.gitignore` and `.dockerignore`), so each build takes the latest.

| plugin                              | for                                         |
|-------------------------------------|---------------------------------------------|
| `selenized.nvim`                    | colorscheme                                 |
| `nvim-lspconfig`                    | language server definitions                 |
| `lsp_signature.nvim`                | signature help popup while typing a call    |
| `nvim-lint`                         | linters without an LSP                      |
| `conform.nvim`                      | formatters / fixers                         |
| `telescope.nvim` (+ `plenary.nvim`) | pickers: files, grep, LSP, diagnostics      |
| `gitsigns.nvim`                     | git gutter, blame                           |
| `hlchunk.nvim`                      | line number highlight for the current chunk |
| `nvim-rooter.lua`                   | cwd to project root                         |

### Treesitter

Installed by nix: neovim is wrapped with every grammar pre-built.

| source                                               | used for                                                |
|------------------------------------------------------|---------------------------------------------------------|
| `nixpkgs#vimPlugins.nvim-treesitter.withAllGrammars` | the plugin, plus parsers and queries for every language |
| `nixpkgs#tree-sitter`                                | tree-sitter CLI, to build a grammar by hand             |

The parser directory is in the (read-only) nix store, so `:TSInstall` can't add parsers (add them via nix), and
`:checkhealth nvim-treesitter` reports it as "not writable"; that error is expected.

### LSP

Configured in `lsp.lua`, installed by nix, server definitions from `nvim-lspconfig`. Every server reports diagnostics
as soon as a file is opened, shown as `[source] (code) message`.

- Format on save: servers that format do so on save, except where conform formats that filetype: `emmylua_ls`
  (stylua formats lua), `rumdl` (conform runs `rumdl fmt`) and `bashls` (conform runs shfmt). Where `biome` is attached
  it is the only server that formats, so `jsonls` and `cssls` don't reformat the same buffer; html is the exception
  (biome's html formatter is off by default), the `html` server formats it, set to biome's / prettier's style
  (`<head>` / `<body>` indented, no blank lines added around them).
- `ty` watches the project's files (needs `nixpkgs#inotify-tools`), so a change made outside nvim, e.g. by Claude, to a
  file that isn't open updates the errors in the files that are. Other servers don't: nvim's watcher covers the whole
  project tree, which is costly in big repos.
- Every server is asked for UTF-16 positions: nvim offers UTF-8 first, which ruff, ty, biome and tombi would pick while
  the others only do UTF-16, and a buffer with both gets its columns wrong after a non-ASCII character.
- `yamlls` only attaches to `yaml` (not lspconfig's `yaml.docker-compose` etc., filetypes nvim never sets).
- No ESLint server: `biome` lints js/ts (the ESLint server needs the project's own ESLint in `node_modules`, and
  there is no node / npm here to install it).
- `biome` starts in any directory, not only in projects with a `biome.json` (lspconfig's default).
- `tombi` validates TOML against schemastore's schemas (e.g. `pyproject.toml`, `Cargo.toml`) and finds
  `~/.config/tombi/config.toml` itself. A comment starting `# tombi:` is read as a tombi directive, so don't start one
  that way.
- `sqruff` (sql): lint + format, diagnostics as you type. Its config is `~/.config/sqruff/.sqruff` (postgres, line
  length 120) where the project has none, see User Configurations.
- `terraformls`: completion, hover and syntax checks for `.tf` (tflint lints). It formats with the terraform CLI, which
  isn't installed, so it only formats on save if `terraform` is on PATH.
- `emmylua_ls` gets the nvim runtime and plugins as libraries (the `vim.*` API, `require("telescope...")`) only in an
  nvim config (`~/.config/nvim`, or a dir named `nvim` with an `init.lua`), so other lua projects aren't cluttered.
- `harper_ls` attaches to every language harper supports: the whole text of prose (markdown, gitcommit, text, html,
  tex, typst, ...), only the comments in code (python, lua, sh, js/ts, rust, go, c, toml, ...). Dialect: Australian.
  Its `SpellCheck` is off (too many false positives on names and code): `typos_lsp` does spelling.

| source                                 | lspconfig name            | used for                       | impl |
|----------------------------------------|---------------------------|--------------------------------|------|
| `nixpkgs#ty`                           | `ty`                      | python                         | rust |
| `nixpkgs#ruff`                         | `ruff`                    | python                         | rust |
| `nixpkgs#emmylua-ls`                   | `emmylua_ls`              | lua                            | rust |
| `nixpkgs#biome`                        | `biome`                   | json, css, js/ts, html         | rust |
| `nixpkgs#rumdl`                        | `rumdl`                   | markdown                       | rust |
| `nixpkgs#tombi`                        | `tombi`                   | toml                           | rust |
| `nixpkgs#sqruff`                       | `sqruff`                  | sql                            | rust |
| `nixpkgs#typos-lsp`                    | `typos_lsp`               | spelling                       | rust |
| `nixpkgs#harper`                       | `harper_ls`               | grammar                        | rust |
| `nixpkgs#jinja-lsp`                    | `jinja_lsp`               | jinja                          | rust |
| `nixpkgs#terraform-ls`                 | `terraformls`             | terraform                      | go   |
| `nixpkgs#bash-language-server`         | `bashls`                  | bash (diagnostics: shellcheck) | ts   |
| `nixpkgs#yaml-language-server`         | `yamlls`                  | yaml                           | ts   |
| `nixpkgs#vim-language-server`          | `vimls`                   | vimscript                      | ts   |
| `nixpkgs#dockerfile-language-server`   | `dockerls`                | dockerfile                     | ts   |
| `nixpkgs#vscode-langservers-extracted` | `jsonls`, `cssls`, `html` | json, css, html                | ts   |

### Lint

Run by `nvim-lint` (`lint_format.lua`), for tools without an LSP, when a file is opened, on leaving insert mode and
after saving. `tflint` reads the saved file (no stdin), so it updates on save.

| source                        | used for   | impl    |
|-------------------------------|------------|---------|
| `nixpkgs#gitlint`             | git        | python  |
| `nixpkgs#yamllint`            | yaml       | python  |
| `nixpkgs#hadolint`            | dockerfile | haskell |
| `nixpkgs#tflint`              | terraform  | go      |
| `nixpkgs#buf`                 | protobuf   | go      |
| `nixpkgs#libxml2` (`xmllint`) | xml        | C       |
| `nixpkgs#j2lint`              | jinja      | python  |

### Format

Run by `conform.nvim` on save (`lint_format.lua`), before the language servers that format (see LSP).

| source                               | used for | impl   |
|--------------------------------------|----------|--------|
| `nixpkgs#stylua`                     | lua      | rust   |
| `nixpkgs#ruff` (fix; format via LSP) | python   | rust   |
| `nixpkgs#shfmt`                      | sh, bash | go     |
| `nixpkgs#rumdl` (`rumdl fmt`)        | markdown | rust   |
| `nixpkgs#buf`                        | protobuf | go     |
| `nixpkgs#libxml2` (`xmllint`)        | xml      | C      |

### User Configurations

User-level configurations in `$XDG_CONFIG_HOME` (`~/.config`, from `home/.config`): line length 120 everywhere. A
project's own configuration file replaces them. nvim uses all of them; "CLI" says whether the tool also finds it when
run from the shell (e.g. by Claude), where "no" means it needs `--config <file>`.

| file                       | for                                    | CLI | project configuration that replaces it        |
|----------------------------|----------------------------------------|-----|-----------------------------------------------|
| `stylua/stylua.toml`       | stylua (also 4 spaces)                 | (1) | `stylua.toml`, `.stylua.toml`                 |
| `ruff/ruff.toml`           | ruff                                   | yes | `ruff.toml`, `pyproject.toml` `[tool.ruff]`   |
| `rumdl/rumdl.toml`         | rumdl (also MD047 off: no required     | yes | `.rumdl.toml`, `rumdl.toml`, `pyproject.toml` |
|                            | final newline)                         |     |                                               |
| `biome/biome.json`         | biome (also 4 spaces)                  | no  | `biome.json`, `biome.jsonc`                   |
| `tombi/config.toml`        | tombi                                  | yes | `tombi.toml`, `.tombi.toml`, `pyproject.toml` |
| `sqruff/.sqruff`           | sqruff (also postgres)                 | (2) | `.sqruff`, `.sqruff.ini`, `sqruff.toml`,      |
|                            |                                        |     | `.sqlfluff`, `pyproject.toml` (2)             |
| `gitlint/gitlint`          | gitlint                                | no  | `.gitlint`                                    |
| `yamllint/config`          | yamllint (no line length)              | yes | `.yamllint`                                   |
| `typos/typos.toml`         | typos word list                        | no  | `.typos.toml` (merged on top)                 |
| `harper-ls/dictionary.txt` | harper word list                       | -   | `.harper-dictionary.txt` (merged on top)      |
| `nvim/.luarc.json`         | emmylua_ls, for the nvim config itself | -   | (it is that folder's project config)          |

(1) only with `stylua --search-parent-directories` (as conform runs it); a plain `stylua file.lua` uses tabs.

(2) sqruff only reads a config in the directory it runs in. Where that has none: nvim starts the sqruff language server
in `~/.config/sqruff` (its server takes no settings or `--config`), and the `sqruff` function in `.zshrc` adds
`--config ~/.config/sqruff/.sqruff` and says so on stderr (`command sqruff` skips it).

### Examples

`example_files_for_nvim_lsp_and_lint/<tool>/` has a file with known problems (diagnostics) or bad formatting for every
language server, linter and formatter above. Open one in nvim to try it, or run `check.lua` headless: it prints the
servers attached (with the features each offers), the linters and formatters for the file, its diagnostics, and what
format on save would change, as a diff (the file is not written). Usage at the top of `check.lua`;
`expected_output.txt` is the output for every example when this setup was last checked.

## Tools

Every tool installed, for you or Claude to use. They come from `nixpkgs` (the `PACKAGES` section of the `Dockerfile`),
except the last table (apt). "impl" is the language each is written in.

### Shell & Terminal

| tool                      | for                                                   | impl |
|---------------------------|-------------------------------------------------------|------|
| `zsh`                     | shell (config: `~/.config/zsh/.zshrc`)                | C    |
| `zsh-fzf-tab`             | tab completion through fzf                            | zsh  |
| `zsh-syntax-highlighting` | highlights the command line as you type               | zsh  |
| `starship`                | prompt                                                | rust |
| `tmux`                    | terminal multiplexer, the session the scripts attach  | C    |

### Editors & Build

| tool                    | for                                                            | impl |
|-------------------------|----------------------------------------------------------------|------|
| `neovim`                | editor (see Nvim), wrapped with nvim-treesitter's grammars     | C    |
| `nano`                  | fallback editor                                                | C    |
| `gcc`                   | C compiler                                                     | C++  |
| `tree-sitter`           | tree-sitter CLI: generate / test / build a grammar             | rust |

### Core CLI

| tool                    | for                                                            | impl |
|-------------------------|----------------------------------------------------------------|------|
| `git`                   | version control (merges use mergiraf, see below)               | C    |
| `less`                  | pager (with `bat` highlighting via `LESSOPEN`)                 | C    |
| `gawk`                  | awk                                                            | C    |
| `wget`, `curl`          | downloads, HTTP                                                | C    |
| `tree`                  | directory tree                                                 | C    |
| `gnutar`, `zip`/`unzip` | archives                                                       | C    |
| `file`                  | identify a file's type                                         | C    |

### Modern Replacements

| tool               | replaces                     | for                                                      | impl |
|--------------------|------------------------------|----------------------------------------------------------|------|
| `ripgrep` (`rg`)   | `grep`                       | search file contents (respects `.gitignore`)             | rust |
| `fd`               | `find`                       | find files                                               | rust |
| `bat`              | `cat` (alias)                | print files with syntax highlighting                     | rust |
| `eza`              | `ls` (alias)                 | list files, with git status                              | rust |
| `sd`               | `sed`                        | find & replace, with normal regex syntax: `sd old new f` | rust |
| `xh`               | `curl`                       | HTTP requests: `xh get url key==value`                   | rust |

### Files & Navigation

| tool                     | for                                                            | impl |
|--------------------------|----------------------------------------------------------------|------|
| `fzf`                    | fuzzy finder: Ctrl+T files, Ctrl+R history, Alt+C cd           | go   |
| `direnv`                 | per-directory env vars (`.envrc`)                              | go   |
| `renameutils`            | bulk rename in your editor (`qmv`, `imv`)                      | C    |

### Data & Documents

| tool              | for                                                                  | impl    |
|-------------------|----------------------------------------------------------------------|---------|
| `jq`              | query / transform json                                               | C       |
| `jaq`             | a faster jq clone (mostly the same syntax)                           | rust    |
| `jc`              | turn command output into json (`ls -l \| jc --ls`)                   | python  |
| `gron`            | make json greppable (one `path = value` per line)                    | go      |
| `yq-go` (`yq`)    | query / transform yaml                                               | go      |
| `jless`           | json viewer: collapsible tree, search                                | rust    |
| `qsv`             | csv toolkit: select, filter, stats, join, ...                        | rust    |
| `csvlens`         | csv viewer                                                           | rust    |
| `hcl2json`        | convert hcl2 (nomad, terraform) to json                              | go      |
| `sta`             | statistics (mean, stddev, ...) of numbers on stdin                   | C++     |
| `pandoc`          | convert between markup formats (markdown, html, docx, ...)           | haskell |

### Code Search, Diffs & Merges

| tool                  | for                                                                       | impl |
|-----------------------|---------------------------------------------------------------------------|------|
| `ast-grep` (`sg`)     | search and rewrite code by its syntax tree                                | rust |
| `delta`               | git's pager: highlighted diffs with line numbers                          | rust |
| `difftastic`          | structural diff: `difft`, `git ddiff`, `git dlog -p`, `git dshow`         | rust |
| `mergiraf`            | git merge driver for every file (`~/.config/git/attributes`): resolves    | rust |
|                       | conflicts that only look like conflicts line by line (e.g. both sides     |      |
|                       | adding an import or a json key); unsupported files get git's own merge    |      |
| `tokei`               | count lines of code                                                       | rust |

### Language Servers, Linters & Formatters

Used by nvim (see Nvim) unless noted; all of them also work on the command line.

| tool                           | for                                                      | impl       |
|--------------------------------|----------------------------------------------------------|------------|
| `ty`                           | python type checker / language server                    | rust       |
| `ruff`                         | python lint + format                                     | rust       |
| `python314Packages.vulture`    | python unused code (CLI only)                            | python     |
| `emmylua-ls`                   | lua language server                                      | rust       |
| `stylua`                       | lua format                                               | rust       |
| `bash-language-server`         | bash language server                                     | typescript |
| `shellcheck`                   | shell lint (through bashls in nvim)                      | haskell    |
| `shfmt`                        | shell format                                             | go         |
| `biome`                        | json, css, js/ts lint + format                           | rust       |
| `vscode-langservers-extracted` | json, css, html language servers                         | typescript |
| `rumdl`                        | markdown lint + format + language server                 | rust       |
| `tombi`                        | toml lint + format + language server, with schemas       | rust       |
| `yaml-language-server`         | yaml language server, with schemas                       | typescript |
| `yamllint`                     | yaml lint                                                | python     |
| `ansible-lint`                 | ansible playbooks lint (CLI only)                        | python     |
| `jinja-lsp`                    | jinja language server                                    | rust       |
| `j2lint`                       | jinja lint                                               | python     |
| `djlint`                       | html template lint + format (CLI only)                   | python     |
| `jinja2-cli`                   | render a jinja template (CLI only)                       | python     |
| `sqruff`                       | sql lint + format                                        | rust       |
| `dockerfile-language-server`   | dockerfile language server                               | typescript |
| `hadolint`                     | dockerfile lint                                          | haskell    |
| `terraform-ls`                 | terraform language server                                | go         |
| `tflint`                       | terraform lint                                           | go         |
| `buf`                          | protobuf lint + format, breaking change checks           | go         |
| `libxml2` (`xmllint`)          | xml lint + format                                        | C          |
| `vim-language-server`          | vimscript language server                                | typescript |
| `gitlint`                      | commit message lint                                      | python     |
| `typos`, `typos-lsp`           | spelling mistakes in code and prose                      | rust       |
| `harper`                       | grammar (`harper-ls`, `harper-cli`)                      | rust       |
| `inotify-tools`                | file watching for nvim's LSP client (ty)                 | C          |

### Security & Links

| tool                 | for                                                                         | impl |
|----------------------|-----------------------------------------------------------------------------|------|
| `gitleaks`           | find leaked credentials in a repo and its history (`gitleaks git -v`)       | go   |
| `ripsecrets`         | find secrets in files, fast (made for pre-commit hooks)                     | rust |
| `lychee`             | broken link checker (markdown, html, ...)                                   | rust |

### Debugging, Profiling & Monitoring

| tool                 | for                                                                         | impl |
|----------------------|-----------------------------------------------------------------------------|------|
| `htop`               | processes                                                                   | C    |
| `lsof`               | open files and sockets                                                      | C    |
| `net-tools`          | `netstat`, `ifconfig`                                                       | C    |
| `lnav`               | log file viewer                                                             | C++  |
| `gdb`                | debugger                                                                    | C    |
| `strace`             | syscall tracer                                                              | C    |
| `py-spy`             | python sampling profiler                                                    | rust |
| `hyperfine`          | benchmark commands against each other                                       | rust |

### Network

| tool                       | for                                                                   | impl |
|----------------------------|-----------------------------------------------------------------------|------|
| `websocat`                 | websocket client                                                      | rust |
| `grpcurl`                  | grpc client                                                           | go   |
| `bind`                     | dns: `dig`, `nslookup`                                                | C    |
| `prometheus.cli`           | `promtool`: check prometheus rules / configs, query a server          | go   |

### Containers & Kubernetes

| tool                       | for                                                                   | impl |
|----------------------------|-----------------------------------------------------------------------|------|
| `docker`                   | docker CLI                                                            | go   |
| `kubectl`                  | kubernetes CLI                                                        | go   |
| `kustomize`                | kubernetes manifests                                                  | go   |
| `dive`                     | explore image layers, find wasted space                               | go   |

### Python

`python3` isn't on PATH: use a micromamba env, or `uv run python`.

| tool                       | for                                                                   | impl |
|----------------------------|-----------------------------------------------------------------------|------|
| `micromamba`               | conda envs (`,m`, `,ca`, `,cr` in `.zshrc`)                           | C++  |
| `uv`                       | venvs, packages, python versions, `uv run`                            | rust |

### Container Runtime & Claude Code

| tool                       | for                                                                   | impl    |
|----------------------------|-----------------------------------------------------------------------|---------|
| `tini`                     | PID 1: reaps zombies, forwards signals so `stop` is immediate         | C       |
| `bubblewrap`, `socat`      | Claude Code's sandbox                                                 | C       |
| `cachix`                   | nix binary cache client                                               | haskell |

### From apt

`build-essential` (also a gcc and `make`), `openssh-client`, `sudo`, `curl`, `tzdata`, `ncurses-term`, and man pages
(`man-db`, `manpages`, `manpages-dev`, `manpages-posix`, `manpages-posix-dev`, `git-man`).
