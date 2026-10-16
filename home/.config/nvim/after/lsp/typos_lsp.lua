-- Personal word list for typos (home/.config/typos/typos.toml); a project's own .typos.toml is merged on top of it
local util = require("config/util")

---@type vim.lsp.Config
return {
    init_options = { config = vim.fs.joinpath(util.config_home, "typos/typos.toml") },
}
