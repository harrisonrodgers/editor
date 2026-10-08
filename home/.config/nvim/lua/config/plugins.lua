-- Plugins are managed by neovim's built-in vim.pack (:help vim.pack). Installed to
-- $XDG_DATA_HOME/nvim/site/pack/core/opt/. The lockfile (nvim-pack-lock.json) is created on first install and
-- deliberately not committed: each build installs whatever is latest upstream.
--   Update:  :lua vim.pack.update()   (review the buffer, :write to confirm, :quit to discard)
--   Remove:  delete the plugin from the list below, then :lua vim.pack.del({ "<name>" })
vim.pack.add({
    -- Theme
    "https://github.com/calind/selenized.nvim",

    -- Misc
    --"https://github.com/unblevable/quick-scope",

    -- Indent indicator
    "https://github.com/shellRaining/hlchunk.nvim",

    -- Light bulb for lsp code actions
    -- "https://github.com/kosayoda/nvim-lightbulb",
    -- -- Put lightbulb in gutter when a lsp code action is available
    -- vim.cmd([[autocmd CursorHold,CursorHoldI * lua require"nvim-lightbulb";.update_lightbulb()]])

    -- Tree-sitter: NOT managed here. Installed via nix in the Dockerfile (neovim wrapped with
    -- vimPlugins.nvim-treesitter.withAllGrammars) to get prebuilt parsers instead of compiling them all.

    -- Used for highlight definitions & highlight scope
    -- "https://github.com/nvim-treesitter/nvim-treesitter-refactor",
    -- should now be replaced by vim.lsp.buf.document_highlight() (or a plugin like RRethy/vim-illuminate) TODO: confirm

    -- Dependencies (Git Gutter, Telescope; telescope's popups come from plenary, the standalone popup.nvim isn't needed)
    "https://github.com/nvim-lua/plenary.nvim",

    -- Telescope
    "https://github.com/nvim-telescope/telescope.nvim",
    -- Possible later: "https://github.com/nvim-telescope/telescope-fzf-native.nvim", a C implementation of the fzf sorter that
    -- speeds up sorting big result lists (find_files / live_grep on large repos); little difference for the small pickers
    -- used now. Adding it needs: a build step (vim.pack doesn't run one: a PackChanged autocmd, defined before
    -- vim.pack.add, that runs `make` in the plugin dir on install/update), `require("telescope").load_extension("fzf")`,
    -- and `nixpkgs#gnumake` in the Dockerfile (it only lists gcc).

    -- Git Gutter
    "https://github.com/lewis6991/gitsigns.nvim",

    -- LSP Config
    "https://github.com/neovim/nvim-lspconfig",

    -- Signature Completion
    "https://github.com/ray-x/lsp_signature.nvim",

    -- Linters that have no LSP (gitlint, yamllint, ...) and formatters (stylua)
    "https://github.com/mfussenegger/nvim-lint",
    "https://github.com/stevearc/conform.nvim",

    -- Misc
    "https://github.com/notjedi/nvim-rooter.lua",
}, {
    -- Don't prompt for the initial install when there is no UI (e.g. the headless Docker build).
    confirm = #vim.api.nvim_list_uis() > 0,
})
