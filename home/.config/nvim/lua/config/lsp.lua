-- Language servers: what applies to all of them. Each server's own settings are in after/lsp/<server>.lua.
local completion = require("config/completion")

local augroup = vim.api.nvim_create_augroup("LspFormatting", {}) -- Format on save

-- Completion, keymaps, symbol highlight and format-on-save, applied whenever a server attaches to a buffer
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local bufnr = args.buf

        -- Format on save
        -- (Servers whose filetype conform formats are excluded, see conform.lua: emmylua_ls (stylua formats lua),
        -- rumdl (conform runs `rumdl fmt` on markdown) and bashls (conform runs shfmt, which bashls would run a second
        -- time). ruff formats python here, but its auto-fixes run through conform's ruff_fix, because the editor-only
        -- lint rules in after/lsp/ruff.lua must not be auto-fixed on save; conform's BufWritePre runs first.)
        -- Where biome is attached it is the only server that formats, so it doesn't fight jsonls/cssls over the same
        -- buffer. Except html: biome's html formatter is off by default, so there the html server formats.
        -- terraformls formats by running the terraform CLI, so only when `terraform` is installed (it isn't, by default).
        -- Whether a server can format is checked when saving, not here: ruff registers formatting dynamically, after
        -- LspAttach, so supports_method() is still false at this point. (Re)creating the autocmd is harmless.
        vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
        vim.api.nvim_create_autocmd("BufWritePre", {
            group = augroup,
            buffer = bufnr,
            callback = function()
                local biome = #vim.lsp.get_clients({ bufnr = bufnr, name = "biome" }) > 0
                    and vim.bo[bufnr].filetype ~= "html"
                local function formats(c)
                    if c.name == "emmylua_ls" or c.name == "rumdl" or c.name == "bashls" then
                        return false
                    end
                    if c.name == "terraformls" and vim.fn.executable("terraform") == 0 then
                        return false
                    end
                    if vim.bo[bufnr].filetype == "html" then
                        return c.name ~= "biome"
                    end
                    return not biome or c.name == "biome"
                end
                if
                    #vim.tbl_filter(formats, vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/formatting" }))
                    > 0
                then
                    -- Sync causes less issues, and ruff is ultra fast
                    vim.lsp.buf.format({ async = false, bufnr = bufnr, filter = formats })
                end
            end,
        })

        -- Use this server's completion items; accepting one (<C-y>) applies its snippet, import edits and commands.
        -- autotrigger also opens the menu on the server's trigger characters (e.g. "."), which 'autocomplete' alone misses
        if client and client:supports_method("textDocument/completion") then
            vim.lsp.completion.enable(true, client.id, bufnr, {
                autotrigger = true,
                convert = completion.convert(client.name),
            })
        end

        -- Signature help popup that opens by itself while you type a call (nvim's own only opens on <C-s>), with the
        -- parameter you are on highlighted. lsp_signature.nvim; hint_enable = false turns off its virtual-text hint.
        if client and client:supports_method("textDocument/signatureHelp") then
            require("lsp_signature").on_attach({
                bind = true,
                handler_opts = { border = "rounded" },
                hint_enable = false,
            }, bufnr)
        end

        -- Opt-in LSP features (off by default), enabled only where the server supports them
        -- Folds from the server (e.g. a function or class body; za toggles, zM closes all, zR opens all)
        if client and client:supports_method("textDocument/foldingRange") then
            local win = vim.api.nvim_get_current_win()
            vim.wo[win][0].foldmethod = "expr"
            vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
        end
        if client and client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        end
        -- Editing an html tag name updates its closing tag (and vice versa)
        if client and client:supports_method("textDocument/linkedEditingRange") then
            vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
        end

        -- Highlight the symbol under the cursor and its other uses in the buffer (textDocument/documentHighlight), after
        -- the cursor rests for 'updatetime' (colors: LspReference* in colorscheme.lua). One group per buffer, cleared
        -- first: a second server (or a restarted one) doesn't add the autocmds again.
        if client and client:supports_method("textDocument/documentHighlight") then
            local group = vim.api.nvim_create_augroup("LspDocumentHighlight" .. bufnr, { clear = true })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                group = group,
                buffer = bufnr,
                callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd("CursorMoved", {
                group = group,
                buffer = bufnr,
                callback = vim.lsp.buf.clear_references,
            })
        end

        -- Code lens (e.g. "Run test", reference counts): shown above lines, run with `grx` on the line
        if client and client:supports_method("textDocument/codeLens") then
            vim.lsp.codelens.enable(true, { bufnr = bufnr })
        end
        -- Inline completion (ghost text from e.g. Copilot's language server): <C-l> accepts it
        if client and client:supports_method("textDocument/inlineCompletion") then
            vim.lsp.inline_completion.enable(true, { bufnr = bufnr })
            vim.keymap.set("i", "<C-l>", function()
                if not vim.lsp.inline_completion.get() then
                    return "<C-l>"
                end
            end, { buffer = bufnr, expr = true, desc = "Accept the current inline completion" })
        end

        -- Mappings.
        -- See `:help vim.lsp.*` for documentation on any of the below functions
        local bufopts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
        vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
        vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
        vim.keymap.set("n", "<space>wl", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, bufopts)

        -- Code structure queries, each only where this server supports it. Under the gr prefix, next to the defaults
        -- (gra, gri, grn, grr, grt, grx): grs workspace symbols, grc/grC callers/callees, grh/grH subtypes/supertypes
        local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
        end
        -- Telescope pickers for the LSP lookups, instead of nvim's quickfix list / direct jump. These shadow the default gr*
        -- mappings and gO in buffers where a server supports the request, so other buffers keep the defaults.
        local function pick(name)
            return function()
                require("telescope.builtin")[name]()
            end
        end
        if client and client:supports_method("textDocument/definition") then
            map("gd", pick("lsp_definitions"), "Definitions")
        end
        if client and client:supports_method("textDocument/references") then
            map("grr", pick("lsp_references"), "References")
        end
        if client and client:supports_method("textDocument/implementation") then
            map("gri", pick("lsp_implementations"), "Implementations")
        end
        if client and client:supports_method("textDocument/typeDefinition") then
            map("grt", pick("lsp_type_definitions"), "Type definitions")
        end
        if client and client:supports_method("textDocument/documentSymbol") then
            map("gO", pick("lsp_document_symbols"), "Symbols in this file")
        end
        if client and client:supports_method("workspace/symbol") then
            -- every class/function/variable in the project, searched by name as you type
            map("grs", pick("lsp_dynamic_workspace_symbols"), "Workspace symbols")
        end
        if client and client:supports_method("textDocument/prepareCallHierarchy") then
            map("grc", pick("lsp_incoming_calls"), "Callers of the symbol under the cursor")
            map("grC", pick("lsp_outgoing_calls"), "Callees of the symbol under the cursor")
        end
        if client and client:supports_method("textDocument/prepareTypeHierarchy") then
            map("grh", function()
                vim.lsp.buf.typehierarchy("subtypes")
            end, "Subtypes (classes inheriting from this)")
            map("grH", function()
                vim.lsp.buf.typehierarchy("supertypes")
            end, "Supertypes (classes this inherits from)")
        end
    end,
})

-- Every server uses UTF-16 positions. nvim offers UTF-8 first, so the servers that support it (ruff, ty, biome, tombi)
-- picked UTF-8 while the rest (harper_ls, typos_lsp, the typescript servers) only do UTF-16: a buffer with both gets its
-- columns wrong after a non-ASCII character, and :checkhealth vim.lsp warns about the mix.
vim.lsp.config("*", { capabilities = { general = { positionEncodings = { "utf-16" } } } })

-- Default cmd/filetypes/root_markers come from nvim-lspconfig's lsp/*.lua, this config's changes from after/lsp/*.lua
vim.lsp.enable({
    "jsonls",
    "yamlls",
    "vimls",
    "bashls",
    "cssls",
    "dockerls",
    "html",
    "ty", -- type checker + inlay hints; ruff does lint/format/imports, they run side by side
    "ruff",
    "emmylua_ls",
    "jinja_lsp",
    "typos_lsp",
    "biome", -- json, css, js/ts, html, ...: lint + format (no eslint server: it needs the project's ESLint and node)
    "rumdl", -- markdown lint; conform formats with `rumdl fmt`
    "tombi", -- toml lint + format + schemas (finds ~/.config/tombi/config.toml itself)
    "sqruff", -- sql lint + format
    "terraformls", -- terraform: completion, hover, syntax errors (lint: tflint; formatting needs the terraform CLI)
    "harper_ls", -- grammar + spelling in prose and comments
})
