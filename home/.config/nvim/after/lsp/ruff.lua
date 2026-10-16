-- ruff: lint + format for python. Formats on save (lua/config/lsp.lua); its auto-fixes run through conform's ruff_fix
-- (lua/config/conform.lua), so the editor-only rules below are never auto-fixed on save.
---@type vim.lsp.Config
return {
    init_options = {
        settings = {
            -- Extra rules only for the errors shown in nvim, on top of each repo's own ruff config. These never touch the
            -- code: auto-fix on save goes through conform (ruff_fix), which only reads the repo's config. Formatting on
            -- save is done by this server, and lint rules don't affect formatting. (A fix applied through this server,
            -- e.g. `gra`, can still use these rules.)
            lint = {
                extendSelect = {
                    "RET",
                    "TID252",
                    "RET505",
                    "RET506",
                    "RET507",
                    "ANN",
                    "PGH",
                    "DTZ003",
                    "DTZ004",
                    "D200",
                    "D205",
                    "D415",
                    "FA100",
                    "FA102",
                    "ICN001",
                },
            },
            -- Options of those rules are not editor settings, so they go in as an inline ruff configuration. "all" makes
            -- TID252 (relative imports) flag every relative import, not only the ones that reach into a parent package.
            configuration = { lint = { ["flake8-tidy-imports"] = { ["ban-relative-imports"] = "all" } } },
        },
    },
}
