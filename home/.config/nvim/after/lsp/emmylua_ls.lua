-- Give emmylua_ls the nvim runtime and the vim.pack plugins, so it knows the vim.* API and the plugins' modules
-- (completion, types, `require`) when editing an nvim config: ~/.config/nvim, or any other dir named nvim with an
-- init.lua (e.g. this repo's home/.config/nvim). Other lua projects don't get them, so their completion isn't full of
-- nvim and plugin internals.
-- (runtime version and the `vim` global are set in home/.config/nvim/.luarc.json, which also marks that folder as the
-- project root. emmylua_ls reads .luarc.json and its own .emmyrc.json, but not .luarc.jsonc.)
-- plenary is left out: its luassert types redefine the global `assert`, and this config never requires plenary itself.
-- It doesn't format on save: stylua does, through conform (see the format on save in lua/config/lsp.lua).
local function is_nvim_config(root)
    return root ~= nil
        and (
            root == vim.fn.stdpath("config")
            or (vim.fs.basename(root) == "nvim" and vim.uv.fs_stat(vim.fs.joinpath(root, "init.lua")) ~= nil)
        )
end

local function nvim_lua_library()
    local library = { vim.env.VIMRUNTIME }
    for _, dir in ipairs(vim.fn.glob(vim.fn.stdpath("data") .. "/site/pack/core/opt/*", false, true)) do
        if vim.fs.basename(dir) ~= "plenary.nvim" then
            table.insert(library, dir)
        end
    end
    -- nvim-treesitter is not a vim.pack plugin: it comes with the nix-wrapped neovim
    for _, dir in ipairs(vim.api.nvim_get_runtime_file("lua/nvim-treesitter", false)) do
        table.insert(library, vim.fs.dirname(vim.fs.dirname(dir)))
    end
    return library
end

---@type vim.lsp.Config
return {
    on_init = function(client)
        if is_nvim_config(client.root_dir) then
            client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
                emmylua = { workspace = { library = nvim_lua_library() } },
            })
            client:notify("workspace/didChangeConfiguration", { settings = client.settings })
        end
    end,
}
