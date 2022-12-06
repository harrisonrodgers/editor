-- nvim-treesitter/nvim-treesitter
require("nvim-treesitter.configs").setup({
	refactor = {
		highlight_definitions = { enable = true },
		highlight_current_scope = { enable = true },
	},
})
