local augroup = vim.api.nvim_create_augroup("LspFormatting", {}) -- Format on save

-- Completion: nvim's built-in completion (:help ins-autocompletion, :help lsp-completion), no plugin.
-- The menu opens as you type, from the sources in 'complete': "o" is the LSP (omnifunc), then words from the current
-- buffer, other windows and other buffers (the ^N suffix caps how many matches each source contributes).
vim.o.autocomplete = true
-- 'autocomplete' is global, so it would also pop a word-completion menu over telescope's prompt as you type
vim.api.nvim_create_autocmd("FileType", {
    pattern = "TelescopePrompt",
    callback = function(ev)
        vim.bo[ev.buf].autocomplete = false
    end,
})
vim.o.complete = "o,.^7,w^3,b^3"
vim.o.completeopt = "menuone,noselect,popup,fuzzy" -- popup: docs next to the item; noselect: nothing is inserted until you pick

-- Per-server tweaks to how an LSP completion item is shown (passed to vim.lsp.completion.enable below):
--   kind column: colored per kind (CompletionKind* groups, see colorscheme.lua)
--   extra column: "[server] detail", so you can tell where an item came from
--   docs popup: the signature (detail) in a code block, followed by the documentation
-- 'pummaxwidth' would cut a long row off from the right, hiding the kind and menu columns, so instead the abbr and menu
-- columns are each limited here (display cells). Only the shown text is cut: the inserted text, the fuzzy matching and
-- the full signature in the docs popup are unaffected.
local ABBR_MAX_WIDTH = 50
local MENU_MAX_WIDTH = 40
local function truncate(text, max_width)
    if vim.fn.strdisplaywidth(text) <= max_width then
        return text
    end
    local chars = vim.fn.strchars(text)
    while chars > 0 and vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, chars)) > max_width - 1 do
        chars = chars - 1
    end
    return vim.fn.strcharpart(text, 0, chars) .. "…"
end

-- The docs popup next to the completion menu is a plain float that nvim creates itself, and 'pumborder' doesn't reach it,
-- so give it the same border as the menu whenever the selection changes. It's recognized by being an unfocusable,
-- minimal-style, scratch float without a border; the later runs catch it after the docs have been resolved and resized.
local function border_docs_popup()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        local buf = vim.api.nvim_win_get_buf(win)
        if
            cfg.relative == "editor"
            and cfg.border == "none"
            and not cfg.focusable
            and cfg.style == "minimal"
            and vim.bo[buf].buftype == "nofile"
            and vim.bo[buf].bufhidden == "wipe"
        then
            vim.api.nvim_win_set_config(win, { border = vim.o.pumborder ~= "" and vim.o.pumborder or "rounded" })
        end
    end
end
vim.api.nvim_create_autocmd("CompleteChanged", {
    callback = function()
        for _, delay in ipairs({ 20, 150, 500 }) do
            vim.defer_fn(border_docs_popup, delay)
        end
    end,
})

local function completion_convert(client_name)
    return function(item)
        local kind = vim.lsp.protocol.CompletionItemKind[item.kind] or "Unknown"
        local detail = item.detail
        local description = vim.tbl_get(item, "labelDetails", "description") or detail or ""
        local doc = type(item.documentation) == "table" and item.documentation.value or item.documentation
        local info
        if detail and detail ~= "" then
            info = ("```%s\n%s\n```"):format(vim.bo.filetype, detail)
            if doc and doc ~= "" then
                info = info .. "\n" .. doc
            end
        end
        return {
            -- same as nvim's default abbr (label + labelDetails.detail), cut to ABBR_MAX_WIDTH
            abbr = truncate(item.label .. (vim.tbl_get(item, "labelDetails", "detail") or ""), ABBR_MAX_WIDTH),
            kind_hlgroup = "CompletionKind" .. kind,
            menu = truncate(("[%s] %s"):format(client_name, (description:gsub("\n.*", ""))), MENU_MAX_WIDTH),
            info = info,
        }
    end
end

-- <Tab>/<S-Tab> move through the menu (or jump between snippet fields), <CR> only accepts an item you selected
local function snippet_jump(direction)
    return vim.snippet.active({ direction = direction }) and ("<Cmd>lua vim.snippet.jump(%d)<CR>"):format(direction)
end
local function complete_or_snippet(direction, pum_key, fallback)
    return function()
        -- A selected snippet placeholder (select mode) always jumps, even if the menu happens to be open
        if vim.fn.mode() ~= "s" and vim.fn.pumvisible() == 1 then
            return pum_key
        end
        return snippet_jump(direction) or fallback
    end
end
vim.keymap.set(
    { "i", "s" },
    "<Tab>",
    complete_or_snippet(1, "<C-n>", "<Tab>"),
    { expr = true, desc = "Next completion item / snippet field" }
)
vim.keymap.set(
    { "i", "s" },
    "<S-Tab>",
    complete_or_snippet(-1, "<C-p>", "<S-Tab>"),
    { expr = true, desc = "Previous completion item / snippet field" }
)

-- <CR> accepts an item you selected (without adding a newline, like nvim-cmp did); with nothing selected it's a newline
vim.keymap.set("i", "<CR>", function()
    if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected ~= -1 then
        return "<C-y>"
    end
    return "<CR>"
end, { expr = true, desc = "Accept the selected completion item, else newline" })

-- Command-line completion for `:`, `/` and `?` (:help cmdline-autocompletion)
vim.o.wildmode = "noselect:lastused,full"
vim.o.wildoptions = "pum,fuzzy"
vim.api.nvim_create_autocmd("CmdlineChanged", {
    pattern = { ":", "/", "?" },
    callback = function()
        vim.fn.wildtrigger()
    end,
})

vim.o.foldlevelstart = 99 -- start with every fold open when a file is opened

-- Completion, keymaps and format-on-save, applied whenever a server attaches to a buffer
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local bufnr = args.buf

        -- Format on save
        -- (lua_ls is excluded: stylua formats lua via conform, see lint_format.lua. ruff formats python here, but its
        -- auto-fixes run through conform's ruff_fix, because the editor-only lint rules below must not be auto-fixed on save;
        -- conform's BufWritePre runs first.) -- TODO: why prefer stylua over lua_lsp?
        -- Whether a server can format is checked when saving, not here: ruff registers formatting dynamically, after
        -- LspAttach, so supports_method() is still false at this point. (Re)creating the autocmd is harmless.
        vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
        vim.api.nvim_create_autocmd("BufWritePre", {
            group = augroup,
            buffer = bufnr,
            callback = function()
                local function formats(c)
                    return c.name ~= "lua_ls"
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
                convert = completion_convert(client.name),
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

-- Ruff defaults to UTF-8 while many servers (and previously pyright) use UTF-16; make ruff use UTF-16 so they agree (avoids column drift on non-ASCII)
vim.lsp.config("ruff", {
    capabilities = { general = { positionEncodings = { "utf-16" } } },
    init_options = {
        settings = {
            -- Extra rules only for the errors shown in nvim, on top of each repo's own ruff config. These never touch the
            -- code: auto-fix on save goes through conform (ruff_fix), which only reads the repo's config. Formatting on
            -- save is done by this server, and lint rules don't affect formatting. (A fix applied through this server,
            -- e.g. `gra`, can still use these rules.)
            lint = {
                extendSelect = {
                    "RET",
                    "TID252",
                    "RET505",
                    "RET506",
                    "RET507",
                    "ANN",
                    "PGH",
                    "DTZ003",
                    "DTZ004",
                    "D200",
                    "D205",
                    "D415",
                    "FA100",
                    "FA102",
                    "ICN001",
                },
            },
            -- Options of those rules are not editor settings, so they go in as an inline ruff configuration. "all" makes
            -- TID252 (relative imports) flag every relative import, not only the ones that reach into a parent package.
            configuration = { lint = { ["flake8-tidy-imports"] = { ["ban-relative-imports"] = "all" } } },
        },
    },
})

-- Personal word list for typos (home/.config/typos/typos.toml); a project's own .typos.toml is merged on top of it
vim.lsp.config("typos_lsp", {
    init_options = { config = vim.fn.expand("~/.config/typos/typos.toml") },
})

-- Give lua_ls the nvim runtime so it knows the vim.* API (completion, types) when editing the nvim config.
-- (runtime version and the `vim` global are set in home/.config/nvim/.luarc.jsonc)
vim.lsp.config("lua_ls", {
    settings = { Lua = { workspace = { library = { vim.env.VIMRUNTIME } } } },
})

-- jinja-lsp only attaches to the "jinja" filetype, which nvim doesn't detect from these extensions on its own
vim.filetype.add({ extension = { jinja = "jinja", jinja2 = "jinja", j2 = "jinja" } })

-- Default cmd/filetypes/root_markers come from nvim-lspconfig's lsp/*.lua
vim.lsp.enable({
    "jsonls",
    "yamlls",
    "vimls",
    "bashls",
    "cssls",
    "eslint",
    "dockerls",
    "html",
    "ty", -- type checker + inlay hints; ruff does lint/format/imports, they run side by side
    "ruff",
    "lua_ls",
    "jinja_lsp",
    "typos_lsp",
})
