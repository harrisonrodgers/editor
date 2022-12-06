local PKGS = {
	-- Packer to manage itself
	"savq/paq-nvim",

	-- Theme
	"ishan9299/nvim-solarized-lua",
	-- "cicervlvs/selenized.nvim";
	-- TODO: https://github.com/jan-warchol/selenized/tree/master/editors/vim

	-- Misc
	--"unblevable/quick-scope";

	-- Indent indicator
	"lukas-reineke/indent-blankline.nvim",

	-- Light bulb for lsp code actions
	-- "kosayoda/nvim-lightbulb";
	-- -- Put lightbulb in gutter when a lsp code action is available
	-- vim.cmd([[autocmd CursorHold,CursorHoldI * lua require"nvim-lightbulb";.update_lightbulb()]])

	-- Tree-sitter install languages & latest language definitions
	-- "nvim-treesitter/nvim-treesitter";, {'do': ':TSUpdate'}
	"nvim-treesitter/nvim-treesitter", -- we call TSInstallSync in Dockerfile

	-- Used for highlight definitions & highlight scope
	"nvim-treesitter/nvim-treesitter-refactor",

	-- Tree-sitter playground (toggle it on using :TSPlaygroundToggle)
	"nvim-treesitter/playground",

	-- Dependencies (Git Gutter, null-ls, Telescope)
	"nvim-lua/plenary.nvim",

	-- Telescope Dependencies
	"nvim-lua/popup.nvim",

	-- Telescope
	"nvim-telescope/telescope.nvim",

	-- Git Gutter
	"lewis6991/gitsigns.nvim",

	-- LSP Config
	"neovim/nvim-lspconfig",

	-- Copmletion Engine
	"hrsh7th/cmp-nvim-lsp", -- CMP completion source for LSP.
	"hrsh7th/cmp-buffer", -- CMP completion source for words from the buffer.
	"hrsh7th/cmp-path", -- CMP completion source for filesystem paths.
	"hrsh7th/cmp-cmdline", -- CMP completion source for vim's cmdline.
	-- TODO: https://github.com/Dosx001/cmp-commit
	-- TODO: https://github.com/lukas-reineke/cmp-rg
	"hrsh7th/nvim-cmp", -- Completion engine.

	-- Snippets engine
	"hrsh7th/cmp-vsnip", -- CMP completion source for vim-vsnip.
	"hrsh7th/vim-vsnip", -- LSP snippet support.

	-- Snippets library
	"rafamadriz/friendly-snippets",

	-- Signature Completion
	"ray-x/lsp_signature.nvim",

	-- LSP for formatting and linters
	"jose-elias-alvarez/null-ls.nvim",

	-- Misc
	"notjedi/nvim-rooter.lua",
}

local function clone_paq()
	local path = vim.fn.stdpath("data") .. "/site/pack/paqs/start/paq-nvim"
	if vim.fn.empty(vim.fn.glob(path)) > 0 then
		vim.fn.system({
			"git",
			"clone",
			"--depth=1",
			"https://github.com/savq/paq-nvim.git",
			path,
		})
	end
end
local function bootstrap_paq()
	clone_paq()
	-- Load Paq
	vim.cmd([[packadd paq-nvim]])
	local paq = require("paq")
	-- Exit nvim after installing plugins
	vim.cmd([[autocmd User PaqDoneInstall quit]])
	-- Read and install packages
	paq(PKGS)
	paq.install()
end
return { bootstrap_paq = bootstrap_paq }
