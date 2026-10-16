-- Editor options

-- Reducing the updatetime will improve responsiveness of the CursorHold autocommand event.
vim.opt.updatetime = 100

-- Number column.
vim.opt.number = true -- Enable line number column.
vim.opt.numberwidth = 1 -- Reduce minimum number of columns for the line number column.

-- Highlighing.
vim.opt.cursorline = true -- Highlight the line that the cursor is on.
vim.opt.colorcolumn = "121" -- Highlight the column specified.

-- Rounded borders on floating windows (diagnostics, hover, ...)
vim.o.winborder = "rounded"

-- Rounded border on the completion popup menu (and its docs popup)
vim.o.pumborder = "rounded"
vim.o.pumheight = 12 -- show at most 12 completion items, scroll for the rest

-- Slight transparency (0-100) for the completion menu and for floating windows
vim.o.pumblend = 10
vim.o.winblend = 10

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
-- nvim only creates the backup dir itself when 'backupdir' is left at its default, so create it here (without it, each
-- write silently skips the backup).
vim.opt.backup = true
local backupdir = vim.fn.stdpath("state") .. "/backup"
vim.fn.mkdir(backupdir, "p")
vim.opt.backupdir = { backupdir .. "//" }

-- Start with every fold open when a file is opened (folds come from the LSP where a server supports it, see lsp.lua)
vim.o.foldlevelstart = 99

-- Configure default splitting locations.
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Clear the search highlight: nvim's default <C-l> already does this (and :diffupdate), so no mapping is needed.
