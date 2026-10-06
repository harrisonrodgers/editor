-- Telescope pickers for files (the LSP ones are bound in lsp.lua, the diagnostics ones in diagnostic.lua)
-- Less margin around the pickers: 90% of the screen's width and height (telescope's default is 80% x 90%)
require("telescope").setup({
	defaults = {
		layout_config = { width = 0.9, height = 0.9 },
	},
})

local function picker(name)
	return function() require("telescope.builtin")[name]() end
end

vim.keymap.set("n", "<space>ff", picker("find_files"), { desc = "Find files" })
vim.keymap.set("n", "<space>fg", picker("live_grep"), { desc = "Live grep" })
vim.keymap.set("n", "<space>fof", picker("oldfiles"), { desc = "Recently opened files" })
vim.keymap.set("n", "<space>fmp", picker("man_pages"), { desc = "Man pages" })
