-- Tools that don't have a language server: nvim-lint for diagnostics, conform for formatting

-- nvim-lint has no built-in xmllint linter, so define one: `xmllint --noout -` reads stdin and reports problems on stderr as
--   -:2: parser error : Opening and ending tag mismatch: b line 2 and a
-- (the lines that follow, with the source line and a ^, don't match the pattern and are skipped)
require("lint").linters.xmllint = {
    cmd = "xmllint",
    stdin = true,
    stream = "stderr",
    args = { "--noout", "-" },
    ignore_exitcode = true,
    parser = require("lint.parser").from_pattern("^%-:(%d+): ([%w ]+) : (.+)$", { "lnum", "severity", "message" }, {
        ["parser error"] = vim.diagnostic.severity.ERROR,
        ["validity error"] = vim.diagnostic.severity.ERROR,
        ["namespace error"] = vim.diagnostic.severity.ERROR,
        ["warning"] = vim.diagnostic.severity.WARN,
    }, { source = "xmllint" }),
}

-- nvim-lint has no built-in j2lint linter, so define one: `j2lint --stdin --json` reads the buffer from stdin and prints
--   {"ERRORS": [{"id": "S4", "message": "...", "line_number": 2, ...}], "WARNINGS": [...]}
-- It exits non-zero whenever there is an error. It only checks Jinja style (jinja-lsp covers syntax and references).
require("lint").linters.j2lint = {
    cmd = "j2lint",
    stdin = true,
    args = { "--stdin", "--json" },
    ignore_exitcode = true,
    parser = function(output, bufnr)
        local ok, decoded = pcall(vim.json.decode, output)
        if not ok or type(decoded) ~= "table" then
            return {}
        end
        -- For templates of a non-HTML format (*.json.j2, *.py.j2, *.conf.j2, ...) drop three rules that fight the output
        -- (nvim-lint args can't vary per buffer, so filter here): S7 (one statement per line) flags inline idioms like
        -- `{{ x }}{% if not loop.last %},{% endif %}`, S6 (no {%- -%}) forbids the whitespace control these outputs
        -- need, and S3 (block indentation) miscounts the nesting after a `{%- for`. Plain *.j2 and *.html.j2 keep all rules.
        local skipped = {}
        local name = vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
        if name:match("%.[^.]+%.j2$") and not name:match("%.html%.j2$") then
            skipped = { S3 = true, S6 = true, S7 = true }
        end
        local diagnostics = {}
        for key, severity in pairs({ ERRORS = vim.diagnostic.severity.ERROR, WARNINGS = vim.diagnostic.severity.WARN }) do
            for _, item in ipairs(decoded[key] or {}) do
                if not skipped[item.id] then
                    table.insert(diagnostics, {
                        lnum = item.line_number - 1,
                        col = 0,
                        severity = severity,
                        message = item.message,
                        code = item.id,
                        source = "j2lint",
                    })
                end
            end
        end
        return diagnostics
    end,
}

-- nvim-lint's gitlint has two problems, fixed here:
--  * it passes the buffer's path as --msg-filename, so gitlint reads the saved file and ignores what is being typed, and
--    diagnostics only refresh on write. nvim-lint already pipes the buffer to stdin, so read that instead.
--  * its parser sets no `source`, so diagnostics show as "[?]". Fill it in.
do
    local gitlint = require("lint").linters.gitlint
    local parse = gitlint.parser
    gitlint.args = { "--staged", "--msg-filename", "-" } -- "-" = stdin; /dev/stdin fails as nvim feeds stdin via a socket
    gitlint.parser = function(...)
        local diagnostics = parse(...)
        for _, d in ipairs(diagnostics) do
            d.source = "gitlint"
        end
        return diagnostics
    end
end

-- markdownlint-cli2 has no user-level config location, so pass ours (line length 120) as the base with --config; a
-- project's own .markdownlint-cli2.jsonc / .markdownlint.jsonc is applied on top of it. Used by nvim-lint and conform.
local markdownlint_config = vim.fn.expand("~/.config/markdownlint/markdownlint.jsonc")
require("lint").linters["markdownlint-cli2"].args = { "--config", markdownlint_config, "-" }

require("lint").linters_by_ft = {
    gitcommit = { "gitlint" },
    yaml = { "yamllint" },
    markdown = { "markdownlint-cli2" },
    dockerfile = { "hadolint" },
    terraform = { "tflint" },
    sql = { "sqlfluff" },
    proto = { "buf_lint" },
    xml = { "xmllint" },
    jinja = { "j2lint" },
}

-- FileType as well as BufReadPost: when a file is opened, BufReadPost can run before its filetype is detected, and
-- then there is no linter to pick, so the first diagnostics would only appear after the first write
vim.api.nvim_create_autocmd({ "FileType", "BufReadPost", "BufWritePost", "InsertLeave" }, {
    callback = function()
        require("lint").try_lint()
    end,
})

require("conform").setup({
    formatters_by_ft = {
        lua = { "stylua" },
        -- Only the repo's ruff config applies here (nvim's extra lint rules in lsp.lua are not used): safe auto-fixes of
        -- the repo's rules (this also sorts imports if the repo selects "I"). The formatting itself is done by the ruff
        -- language server, see the format on save in lsp.lua.
        python = { "ruff_fix" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        markdown = { "markdownlint-cli2" }, -- runs `markdownlint-cli2 --fix`
        proto = { "buf" },
        xml = { "xmllint" },
        sql = { "sqlfluff" },
    },
    formatters = {
        ["markdownlint-cli2"] = { args = { "--config", markdownlint_config, "--fix", "$FILENAME" } },
        -- sqlfluff needs a dialect; default to postgres and don't require a .sqlfluff project root
        sqlfluff = { require_cwd = false, args = { "fix", "--dialect", "postgres", "-" } },
    },
    format_on_save = { timeout_ms = 2000, lsp_format = "never" },
})
