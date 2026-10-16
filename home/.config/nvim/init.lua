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

require("config/options")
require("config/autocmds")
require("config/colorscheme")
require("config/lint") -- nvim-lint, for tools without an LSP (custom linters in lua/config/lint/)
require("config/conform") -- formatters; before lsp.lua, so its BufWritePre runs before the LSP format on save
require("config/completion")
require("config/lsp") -- what applies to every server; each server's settings are in after/lsp/<server>.lua
require("config/telescope")
require("config/diagnostic")
require("config/gitsigns")
require("config/hlchunk")
require("config/start_screen") -- key cheat sheet shown when nvim is started without a file

require("config/rooter")
require("config/treesitter")

-- Built-in plugins that are not loaded by default
vim.cmd.packadd("nvim.undotree") -- :Undotree, visual undo-tree navigator
vim.cmd.packadd("nvim.difftool") -- :DiffTool {left} {right}, compare two files or directories
