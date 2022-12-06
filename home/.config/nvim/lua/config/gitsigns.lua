-- Configure gitsigns
require("gitsigns").setup({
	signs = {
		add = { hl = "GitSignsAdd", text = " ", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
		change = { hl = "GitSignsChange", text = " ", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
		delete = { hl = "GitSignsDelete", text = " ", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
		topdelete = { hl = "GitSignsDelete", text = " ", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
		changedelete = { hl = "GitSignsDelete", text = " ", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
	},
	-- TODO: keymaps config https://github.com/lewis6991/gitsigns.nvim
	keymaps = {
		["n gb"] = '<cmd>lua require"gitsigns".blame_line(true)<CR>',
	},
})

-- Configure gitsigns highlights
vim.api.nvim_set_hl(0, "GitSignsAdd", { bg = "#E2E9C1" })
vim.api.nvim_set_hl(0, "GitSignsChange", { bg = "#DDE4F2" })
vim.api.nvim_set_hl(0, "GitSignsDelete", { bg = "#F7E0C3" })
