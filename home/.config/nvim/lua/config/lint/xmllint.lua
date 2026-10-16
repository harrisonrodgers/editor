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
