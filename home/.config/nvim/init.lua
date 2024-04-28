-- https://github.com/savq/paq-nvim/blob/master/doc/paq-nvim.txt
-- TODO: read lazy lading section

-- PROVIDERS: improve startup speed by disabling those not needed
vim.g.loaded_python_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0

-- PROVIDERS: improve startup speed by specifying path & avoid virtualenv issues
--vim.g.python_host_prog = '/bin/python2'
--vim.g.python3_host_prog = '/bin/python3'

require("config/colorscheme")
--require("config/null-ls") -- being replaced with ruff_lsp
require("config/lsp_cmp_snip")
require("config/diagnostic")
require("config/indent-blankline")
require("config/nvim-treesitter")
require("config/nvim-treesitter-refactor")
require("config/gitsigns")

-- notjedi/nvim-rooter.lua
require("nvim-rooter").setup()

-- Reducing the updatetime will improve responsiveness of the CursorHold autocommand event.
vim.opt.updatetime = 100

-- Number column.
vim.opt.number = true -- Enable line number column.
vim.opt.numberwidth = 1 -- Reduce minimum number of columns for the line number column.

-- Highlighing.
vim.opt.cursorline = true -- Highlight the line that the cursor is on.
vim.opt.colorcolumn = "121" -- Highlight the column specified.

-- Spaces and Tabs.
vim.opt.expandtab = true -- Use spaces instead of tabs.
vim.opt.tabstop = 4 -- Set the number of spaces a tab takes up.
vim.opt.shiftwidth = 4 -- Set the nummber of spaces to use for (auto)indent.

-- Show special characters (tabs as ">", trailing spaces as "-", non-breakable space as "+")
vim.opt.list = true

-- Searching.
vim.opt.ignorecase = true -- Ignore case in search patters.
vim.opt.smartcase = true -- Overwrite ignorecase if search pattern contains an uppercase.

-- Minimum number of lines to keep above and below the cursor.
vim.opt.scrolloff = 1

-- Enable spell checking.
vim.opt.spell = true

-- Enable mouse.
vim.opt.mouse = "a"

-- Enable autoindenting when starting a new line.
vim.opt.smartindent = true

-- Increase number of undo levels, and enable storing a history file for use after closing and reopening.
vim.opt.undolevels = 50000
vim.opt.undoreload = 50000
vim.opt.undofile = true

-- Enable storing a backup before overwriting a file.
vim.opt.backup = true
vim.opt.backupdir = { vim.env.HOME .. "/.local/state/nvim/backup//" }

-- Configure default splitting locations.
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Bind clear search highlight to window redraw
vim.keymap.set("n", "<C-l>", ":nohlsearch<CR><C-l>", { noremap = true })

-- Place mouse at last location TODO: should be able to use mkview to save cursor position instead of this
vim.cmd([[autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif]])

-- Eager autoreload if file changed on disk (e.g. auto-formatter, auto-linter)
vim.cmd([[autocmd FocusGained * checktime]])
