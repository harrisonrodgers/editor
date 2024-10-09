-- Configure gitsigns (https://github.com/lewis6991/gitsigns.nvim)
require("gitsigns").setup({
    signs = {
        add = { text = " " },
        change = { text = " " },
        delete = { text = " " },
        topdelete = { text = " " },
        changedelete = { text = " " },
    },
    vim.api.nvim_set_hl(0, 'GitSignsAdd', { link = 'GitSignsAdd' }),
    vim.api.nvim_set_hl(0, 'GitSignsAddLn', { link = 'GitSignsAddLn' }),
    vim.api.nvim_set_hl(0, 'GitSignsAddNr', { link = 'GitSignsAddNr' }),
    vim.api.nvim_set_hl(0, 'GitSignsChange', { link = 'GitSignsChange' }),
    vim.api.nvim_set_hl(0, 'GitSignsChangeLn', { link = 'GitSignsChangeLn' }),
    vim.api.nvim_set_hl(0, 'GitSignsChangeNr', { link = 'GitSignsChangeNr' }),
    vim.api.nvim_set_hl(0, 'GitSignsChangedelete', { link = 'GitSignsDelete' }),
    vim.api.nvim_set_hl(0, 'GitSignsChangedeleteLn', { link = 'GitSignsDeleteLn' }),
    vim.api.nvim_set_hl(0, 'GitSignsChangedeleteNr', { link = 'GitSignsDeleteNr' }),
    vim.api.nvim_set_hl(0, 'GitSignsDelete', { link = 'GitSignsDelete' }),
    vim.api.nvim_set_hl(0, 'GitSignsDeleteLn', { link = 'GitSignsDeleteLn' }),
    vim.api.nvim_set_hl(0, 'GitSignsDeleteNr', { link = 'GitSignsDeleteNr' }),
    vim.api.nvim_set_hl(0, 'GitSignsTopdelete', { link = 'GitSignsDelete' }),
    vim.api.nvim_set_hl(0, 'GitSignsTopdeleteLn', { link = 'GitSignsDeleteLn' }),
    vim.api.nvim_set_hl(0, 'GitSignsTopdeleteNr', { link = 'GitSignsDeleteNr' }),
    on_attach = function(bufnr)
        local gitsigns = require('gitsigns')
        local bufopts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set("n", "gb", function() gitsigns.blame_line{full=true} end, bufopts)
    end
})

-- Configure gitsigns highlights
vim.api.nvim_set_hl(0, "GitSignsAdd", { bg = "#E2E9C1" })
vim.api.nvim_set_hl(0, "GitSignsChange", { bg = "#DDE4F2" })
vim.api.nvim_set_hl(0, "GitSignsDelete", { bg = "#F7E0C3" })
