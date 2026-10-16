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
