vim.opt.termguicolors = true
vim.opt.background = "light"
vim.g.solarized_termtrans = 1
vim.cmd([[colorscheme solarized]])

-- Ensure comments are always italic
vim.cmd([[highlight Comment gui=italic]])

-- TODO: figure out how to set just the italic field without resetting the rest of the settings (e.g. the theme's color)
--vim.api.nvim_set_hl(0, "Comment", { italic = true })
