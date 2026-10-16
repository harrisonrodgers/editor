-- sqruff: SQL lint + format (a Rust rewrite of sqlfluff, same rules). Its language server takes no settings (and ignores
-- --config): it only reads a config file in its workspace root. So a project with its own sqruff config is the root;
-- otherwise it's ~/.config/sqruff, which holds the user config (postgres, line length 120; sqruff's own defaults are
-- ansi and 80). The `sqruff` function in .zshrc uses the same file on the command line.
local util = require("config/util")

local function sqruff_project_root(bufnr)
    local root = vim.fs.root(bufnr, { ".sqruff", ".sqruff.ini", "sqruff.toml", ".sqlfluff" })
    if root then
        return root
    end
    local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
    local pyproject = vim.fs.find("pyproject.toml", { path = dir, upward = true })[1]
    if
        pyproject
        and vim.iter(io.lines(pyproject)):any(function(line)
            return vim.startswith(line, "[tool.sqruff")
        end)
    then
        return vim.fs.dirname(pyproject)
    end
end

---@type vim.lsp.Config
return {
    root_dir = function(bufnr, on_dir)
        local user_dir = vim.fs.joinpath(util.config_home, "sqruff")
        local root = sqruff_project_root(bufnr)
        if not root and vim.uv.fs_stat(vim.fs.joinpath(user_dir, ".sqruff")) then
            root = user_dir
        end
        -- no root at all (no user config either): sqruff runs with its defaults
        on_dir(root or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
    end,
}
