-- nvim-treesitter/nvim-treesitter (not a vim.pack plugin: it comes with the nix-wrapped neovim, with its grammars)
-- Point the install dir at the nix-provided prebuilt grammars so :checkhealth lists them as installed.
-- (The dir is read-only, so :TSInstall can't add new parsers; add them via nix instead.)
do
    local grammars = vim.api.nvim_get_runtime_file("parser/lua.so", true)
    for _, so in ipairs(grammars) do
        if so:find("nvim-treesitter-grammars", 1, true) then
            require("nvim-treesitter").setup({ install_dir = vim.fs.dirname(vim.fs.dirname(so)) })
            break
        end
    end
end

-- Treesitter highlighting for every filetype that has a parser (pcall: the others keep nvim's regex syntax)
vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)
    end,
})
