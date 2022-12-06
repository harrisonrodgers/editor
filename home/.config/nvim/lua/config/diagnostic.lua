-- See `:help vim.diagnostic.*` for documentation on any of the below functions.

vim.diagnostic.config({
	virtual_text = true,
	signs = true,
	underline = false,
	update_in_insert = true,
	severity_sort = true,
})

vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, { noremap = true, silent = true })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { noremap = true, silent = true })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { noremap = true, silent = true })
vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist, { noremap = true, silent = true })

-- Setup space saving signs by highlighting the number column.
vim.fn.sign_define("DiagnosticSignError", { text = "", texthl = "", linehl = "", numhl = "DiagnosticSignError" })
vim.fn.sign_define("DiagnosticSignWarn", { text = "", texthl = "", linehl = "", numhl = "DiagnosticSignWarn" })
vim.fn.sign_define("DiagnosticSignInfo", { text = "", texthl = "", linehl = "", numhl = "DiagnosticSignInfo" })
vim.fn.sign_define("DiagnosticSignHint", { text = "", texthl = "", linehl = "", numhl = "DiagnosticSignHint" })

-- Set the background of the number column to indicate the diagnostic
vim.api.nvim_set_hl(0, "DiagnosticSignError", { bold = true, fg = "#dc322f", bg = "#f7d6c3", sp = "None" })
vim.api.nvim_set_hl(0, "DiagnosticSignWarn", { bold = true, fg = "#b58900", bg = "#f7e0c3", sp = "None" })
vim.api.nvim_set_hl(0, "DiagnosticSignInfo", { bold = true, fg = "#268bd2", bg = "#e5e4e2", sp = "None" })
vim.api.nvim_set_hl(0, "DiagnosticSignHint", { bold = true, fg = "#859900", bg = "#e2e9c1", sp = "None" })
