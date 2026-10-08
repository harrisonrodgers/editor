-- Plugins: see lua/config/plugins.lua (built-in vim.pack)
require("config/plugins") -- must come first: puts the plugins on the runtimepath for the requires below

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
require("config/lint_format") -- nvim-lint + conform, for tools without an LSP
require("config/lsp")
require("config/telescope")
require("config/diagnostic")
require("config/gitsigns")
require("config/hlchunk")
require("config/start_screen") -- key cheat sheet shown when nvim is started without a file

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

-- Linewise visual mode (V): highlight the whole width of the selected lines, not just up to the end of the text.
-- nvim has no option for this, so while in V mode the selected lines get a Visual-colored extmark that reaches the edge.
do
    local ns = vim.api.nvim_create_namespace("linewise_visual")
    local function clear(buf)
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
    local function update()
        local buf = vim.api.nvim_get_current_buf()
        clear(buf)
        if vim.fn.mode() ~= "V" then
            return
        end
        local first, last = vim.fn.line("v"), vim.fn.line(".")
        if first > last then
            first, last = last, first
        end
        vim.api.nvim_buf_set_extmark(
            buf,
            ns,
            first - 1,
            0,
            { end_row = last, end_col = 0, hl_group = "Visual", hl_eol = true }
        )
    end
    vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved" }, {
        callback = function(ev)
            if
                ev.event == "ModeChanged"
                and not vim.v.event.new_mode:match("^V")
                and not vim.v.event.old_mode:match("^V")
            then
                return
            end
            update()
        end,
    })
end

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

-- Built-in plugins that are not loaded by default
vim.cmd.packadd("nvim.undotree") -- :Undotree, visual undo-tree navigator
vim.cmd.packadd("nvim.difftool") -- :DiffTool {left} {right}, compare two files or directories

-- Enable storing a backup before overwriting a file.
vim.opt.backup = true
vim.opt.backupdir = { vim.env.HOME .. "/.local/state/nvim/backup//" }

-- Configure default splitting locations.
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Bind clear search highlight to window redraw
vim.keymap.set("n", "<C-l>", ":nohlsearch<CR><C-l>", { noremap = true })

-- Place mouse at last location
-- -- TODO: should be able to use mkview to save cursor position instead of this
-- -- TODO: disable this for git commit
vim.cmd([[autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif]])

-- Eager autoreload if file changed on disk (e.g. auto-formatter, auto-linter, LLM)
vim.cmd([[autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() != 'c' | checktime | endif]])

-- nvim-treesitter/nvim-treesitter
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
vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)
    end,
})

-- Try to enable the "highlight the symbol under the cursor and it's usages" via LSP -- TODO: verify this is working
vim.api.nvim_set_hl(0, "LspReferenceText", { bg = "#E5E4E2" })
vim.api.nvim_set_hl(0, "LspReferenceRead", { bg = "#ebe5d1" })
vim.api.nvim_set_hl(0, "LspReferenceWrite", { bg = "#E5E4E2" })

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client:supports_method("textDocument/documentHighlight") then
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                buffer = args.buf,
                callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd("CursorMoved", {
                buffer = args.buf,
                callback = vim.lsp.buf.clear_references,
            })
        end
    end,
})
