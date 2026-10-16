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
