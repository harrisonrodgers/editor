-- nvim-lint's gitlint has three problems, fixed here:
--  * it passes the buffer's path as --msg-filename, so gitlint reads the saved file and ignores what is being typed, and
--    diagnostics only refresh on write. nvim-lint already pipes the buffer to stdin, so read that instead.
--  * gitlint only reads a .gitlint in the repo (or --config), never ~/.config/gitlint/gitlint, so pass that file when
--    the repo has no .gitlint of its own (a function linter, so it's checked on every run).
--  * its parser sets no `source`, so diagnostics show as "[?]". Fill it in.
local gitlint = require("lint").linters.gitlint
local parse = gitlint.parser
-- fail with a clear message if a newer nvim-lint changes its gitlint parser into something this can't wrap
assert(
    type(parse) == "function",
    "nvim-lint's gitlint parser is no longer a function: update lua/config/lint/gitlint.lua"
)
gitlint.parser = function(...)
    local diagnostics = parse(...)
    for _, d in ipairs(diagnostics) do
        d.source = "gitlint"
    end
    return diagnostics
end
local user_config = vim.fs.joinpath(require("config/util").config_home, "gitlint/gitlint")
require("lint").linters.gitlint = function()
    local args = { "--staged", "--msg-filename", "-" } -- "-" = stdin; /dev/stdin fails as nvim feeds stdin via a socket
    local root = vim.fs.root(0, ".git")
    if not (root and vim.uv.fs_stat(vim.fs.joinpath(root, ".gitlint"))) and vim.uv.fs_stat(user_config) then
        args = vim.list_extend({ "--config", user_config }, args)
    end
    return vim.tbl_extend("force", gitlint, { args = args })
end
