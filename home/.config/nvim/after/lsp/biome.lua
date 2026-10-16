-- biome: lint + format for json, css, js/ts, html, graphql, ... nvim-lspconfig only starts it in projects with a
-- biome.json, so start it everywhere (root: the project, else the file's directory). Without a project biome.json the
-- user-level ~/.config/biome/biome.json is used (line width 120, spaces).
-- Where it's attached it is the only server that formats, except html (see the format on save in lua/config/lsp.lua).
local util = require("config/util")

---@type vim.lsp.Config
return {
    workspace_required = false,
    root_dir = function(bufnr, on_dir)
        local markers = { "biome.json", "biome.jsonc", "package.json", ".git" }
        on_dir(vim.fs.root(bufnr, markers) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
    end,
    before_init = function(_, config)
        local path = util.user_config(config.root_dir, { "biome.json", "biome.jsonc" }, "biome/biome.json")
        config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
            biome = { configurationPath = path, requireConfiguration = false },
        })
    end,
}
