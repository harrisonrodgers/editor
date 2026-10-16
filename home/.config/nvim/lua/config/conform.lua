-- conform: formatters for tools that don't have a language server, plus a few fixers whose language server only
-- reports (e.g. `rumdl fmt` next to the rumdl language server). Runs before the language servers that format (see the
-- format on save in lsp.lua).
---@diagnostic disable-next-line: param-type-mismatch -- valid conform options; emmylua mis-infers this nested table
require("conform").setup({
    formatters_by_ft = {
        lua = { "stylua" },
        -- Only the repo's ruff config applies here (nvim's extra lint rules in after/lsp/ruff.lua are not used): safe
        -- auto-fixes of the repo's rules (this also sorts imports if the repo selects "I"). The formatting itself is done
        -- by the ruff language server, see the format on save in lsp.lua.
        python = { "ruff_fix" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        -- `rumdl fmt`: fixes what it can (line length 120 from ~/.config/rumdl/rumdl.toml, unless the project has its
        -- own config). The rumdl language server shows the diagnostics, see lsp.lua.
        markdown = { "rumdl" },
        proto = { "buf" },
        xml = { "xmllint" },
    },
    format_on_save = { timeout_ms = 2000, lsp_format = "never" },
})
