-- Tools that don't have a language server: nvim-lint for diagnostics, conform for formatting (conform also runs a few
-- fixers whose language server only reports, e.g. `rumdl fmt` next to the rumdl language server)

-- nvim-lint has no built-in xmllint linter, so define one: `xmllint --noout -` reads stdin and reports problems on stderr as
--   -:2: parser error : Opening and ending tag mismatch: b line 2 and a
-- (the lines that follow, with the source line and a ^, don't match the pattern and are skipped)
require("lint").linters.xmllint = {
    name = "xmllint",
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
    name = "j2lint",
    cmd = "j2lint",
    stdin = true,
    args = { "--stdin", "--json" },
    ignore_exitcode = true,
    ---@param output string
    ---@param bufnr number
    ---@return vim.Diagnostic[]
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
        ---@diagnostic disable-next-line: param-type-mismatch -- nvim-lint types bufnr as `number`; it is a buffer handle
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

-- nvim-lint's gitlint has three problems, fixed here:
--  * it passes the buffer's path as --msg-filename, so gitlint reads the saved file and ignores what is being typed, and
--    diagnostics only refresh on write. nvim-lint already pipes the buffer to stdin, so read that instead.
--  * gitlint only reads a .gitlint in the repo (or --config), never ~/.config/gitlint/gitlint, so pass that file when
--    the repo has no .gitlint of its own (a function linter, so it's checked on every run).
--  * its parser sets no `source`, so diagnostics show as "[?]". Fill it in.
do
    local gitlint = require("lint").linters.gitlint
    local parse = gitlint.parser
    -- fail with a clear message if a newer nvim-lint changes its gitlint parser into something this can't wrap
    assert(type(parse) == "function", "nvim-lint's gitlint parser is no longer a function: update lint_format.lua")
    gitlint.parser = function(...)
        local diagnostics = parse(...)
        for _, d in ipairs(diagnostics) do
            d.source = "gitlint"
        end
        return diagnostics
    end
    local user_config = vim.fs.joinpath(vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config"), "gitlint/gitlint")
    require("lint").linters.gitlint = function()
        local args = { "--staged", "--msg-filename", "-" } -- "-" = stdin; /dev/stdin fails as nvim feeds stdin via a socket
        local root = vim.fs.root(0, ".git")
        if not (root and vim.uv.fs_stat(vim.fs.joinpath(root, ".gitlint"))) and vim.uv.fs_stat(user_config) then
            args = vim.list_extend({ "--config", user_config }, args)
        end
        return vim.tbl_extend("force", gitlint, { args = args })
    end
end

-- nvim-lint's buf_lint puts the rule (e.g. PACKAGE_DEFINED) in `source`, so diagnostics show as "[PACKAGE_DEFINED]"
-- with no code. Show them as "[buf] (PACKAGE_DEFINED)" like the others.
do
    local buf_lint = require("lint").linters.buf_lint
    local parse = buf_lint.parser
    assert(type(parse) == "function", "nvim-lint's buf_lint parser is no longer a function: update lint_format.lua")
    buf_lint.parser = function(...)
        local diagnostics = parse(...)
        for _, d in ipairs(diagnostics) do
            d.code, d.source = d.source, "buf"
        end
        return diagnostics
    end
end

-- nvim-lint's tflint runs `tflint --recursive` in nvim's working directory, but matches the results against the file's
-- path relative to the working directory at the time it parses them. nvim-rooter changes the working directory in
-- between (on opening a file below the project root), and then nothing matches: no diagnostics. Its line and column
-- numbers are also off by one. So define it again: lint the file's own directory (a terraform module is a directory),
-- keep only this file's issues, and report the rule name as the code.
require("lint").linters.tflint = function()
    return {
        name = "tflint",
        cmd = "tflint",
        args = { "--format=json", "--filter=" .. vim.fn.expand("%:t") },
        cwd = vim.fn.expand("%:p:h"),
        stdin = false,
        append_fname = false,
        ignore_exitcode = true, -- exit code 2 = issues found
        ---@param output string
        ---@return vim.Diagnostic[]
        parser = function(output)
            local ok, decoded = pcall(vim.json.decode, output)
            if not ok or type(decoded) ~= "table" then
                return {}
            end
            local severities = {
                error = vim.diagnostic.severity.ERROR,
                warning = vim.diagnostic.severity.WARN,
                notice = vim.diagnostic.severity.INFO,
            }
            local diagnostics = {}
            for _, issue in ipairs(decoded.issues or {}) do
                local range = issue.range
                table.insert(diagnostics, {
                    lnum = range.start.line - 1,
                    col = range.start.column - 1,
                    end_lnum = range["end"].line - 1,
                    end_col = range["end"].column - 1,
                    severity = severities[issue.rule.severity] or vim.diagnostic.severity.WARN,
                    message = issue.message,
                    code = issue.rule.name,
                    source = "tflint",
                })
            end
            -- errors: the file (or another in its module) doesn't parse, or the config is invalid
            for _, err in ipairs(decoded.errors or {}) do
                local start = vim.tbl_get(err, "range", "start") or { line = 1, column = 1 }
                table.insert(diagnostics, {
                    lnum = start.line - 1,
                    col = start.column - 1,
                    severity = vim.diagnostic.severity.ERROR,
                    message = err.message,
                    source = "tflint",
                })
            end
            return diagnostics
        end,
    }
end

require("lint").linters_by_ft = {
    gitcommit = { "gitlint" },
    yaml = { "yamllint" },
    dockerfile = { "hadolint" },
    terraform = { "tflint" },
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

---@diagnostic disable-next-line: param-type-mismatch -- valid conform options; emmylua mis-infers this nested table
require("conform").setup({
    formatters_by_ft = {
        lua = { "stylua" },
        -- Only the repo's ruff config applies here (nvim's extra lint rules in lsp.lua are not used): safe auto-fixes of
        -- the repo's rules (this also sorts imports if the repo selects "I"). The formatting itself is done by the ruff
        -- language server, see the format on save in lsp.lua.
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
