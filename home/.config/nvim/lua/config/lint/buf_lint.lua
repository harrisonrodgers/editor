-- nvim-lint's buf_lint puts the rule (e.g. PACKAGE_DEFINED) in `source`, so diagnostics show as "[PACKAGE_DEFINED]"
-- with no code. Show them as "[buf] (PACKAGE_DEFINED)" like the others.
local buf_lint = require("lint").linters.buf_lint
local parse = buf_lint.parser
assert(
    type(parse) == "function",
    "nvim-lint's buf_lint parser is no longer a function: update lua/config/lint/buf_lint.lua"
)
buf_lint.parser = function(...)
    local diagnostics = parse(...)
    for _, d in ipairs(diagnostics) do
        d.code, d.source = d.source, "buf"
    end
    return diagnostics
end
