-- Helpers shared by the config files (after/lsp/*.lua, lua/config/lint/*.lua)
local M = {}

M.config_home = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")

-- A project's own config file wins; without one, the user-level config in $XDG_CONFIG_HOME is used
function M.user_config(root_dir, project_files, user_file)
    for _, name in ipairs(project_files) do
        if root_dir and vim.uv.fs_stat(vim.fs.joinpath(root_dir, name)) then
            return nil
        end
    end
    local path = vim.fs.joinpath(M.config_home, user_file)
    return vim.uv.fs_stat(path) and path or nil
end

return M
