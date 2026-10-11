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
            ---@diagnostic disable-next-line: assign-type-mismatch -- 'pumborder' takes the same border names as a window
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
        -- (Servers whose filetype conform formats are excluded, see lint_format.lua: emmylua_ls (stylua formats lua),
        -- rumdl (conform runs `rumdl fmt` on markdown) and bashls (conform runs shfmt, which bashls would run a second
        -- time). ruff formats python here, but its auto-fixes run through conform's ruff_fix, because the editor-only
        -- lint rules below must not be auto-fixed on save; conform's BufWritePre runs first.)
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

-- Every server uses UTF-16 positions. nvim offers UTF-8 first, so the servers that support it (ruff, ty, biome, tombi)
-- picked UTF-8 while the rest (harper_ls, typos_lsp, the typescript servers) only do UTF-16: a buffer with both gets its
-- columns wrong after a non-ASCII character, and :checkhealth vim.lsp warns about the mix.
vim.lsp.config("*", { capabilities = { general = { positionEncodings = { "utf-16" } } } })

-- ruff: extra lint rules in the editor (see below)
vim.lsp.config("ruff", {
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

-- ty: let it watch the project's files, so a change made outside nvim (by Claude, git, a formatter) to a file that isn't
-- open updates the errors in the files that are (e.g. a changed function signature). nvim only offers file watching on
-- Linux when asked: it watches the whole project with inotifywait (inotify-tools, see the Dockerfile), so only ty has it.
vim.lsp.config("ty", {
    capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } },
})

-- Personal word list for typos (home/.config/typos/typos.toml); a project's own .typos.toml is merged on top of it
vim.lsp.config("typos_lsp", {
    init_options = { config = vim.fn.expand("~/.config/typos/typos.toml") },
})

-- jsonls sets no `source` on its JSON Schema diagnostics (its syntax ones say "json"), so they show as "[?]". Fill it in,
-- for both ways it sends them: pushed (publishDiagnostics) and pulled by nvim (textDocument/diagnostic).
local function with_json_source(diagnostics)
    for _, d in ipairs(diagnostics or {}) do
        d.source = d.source or "json"
    end
end
vim.lsp.config("jsonls", {
    handlers = {
        ["textDocument/publishDiagnostics"] = function(err, result, ctx)
            with_json_source(result and result.diagnostics)
            return vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
        end,
        ["textDocument/diagnostic"] = function(err, result, ctx)
            with_json_source(result and result.items)
            return vim.lsp.diagnostic.on_diagnostic(err, result, ctx)
        end,
    },
})

-- Give emmylua_ls the nvim runtime and the vim.pack plugins, so it knows the vim.* API and the plugins' modules
-- (completion, types, `require`) when editing an nvim config: ~/.config/nvim, or any other dir named nvim with an
-- init.lua (e.g. this repo's home/.config/nvim). Other lua projects don't get them, so their completion isn't full of
-- nvim and plugin internals.
-- (runtime version and the `vim` global are set in home/.config/nvim/.luarc.json, which also marks that folder as the
-- project root. emmylua_ls reads .luarc.json and its own .emmyrc.json, but not .luarc.jsonc.)
-- plenary is left out: its luassert types redefine the global `assert`, and this config never requires plenary itself.
local function is_nvim_config(root)
    return root ~= nil
        and (
            root == vim.fn.stdpath("config")
            or (vim.fs.basename(root) == "nvim" and vim.uv.fs_stat(vim.fs.joinpath(root, "init.lua")) ~= nil)
        )
end
local function nvim_lua_library()
    local library = { vim.env.VIMRUNTIME }
    for _, dir in ipairs(vim.fn.glob(vim.fn.stdpath("data") .. "/site/pack/core/opt/*", false, true)) do
        if vim.fs.basename(dir) ~= "plenary.nvim" then
            table.insert(library, dir)
        end
    end
    -- nvim-treesitter is not a vim.pack plugin: it comes with the nix-wrapped neovim
    for _, dir in ipairs(vim.api.nvim_get_runtime_file("lua/nvim-treesitter", false)) do
        table.insert(library, vim.fs.dirname(vim.fs.dirname(dir)))
    end
    return library
end
vim.lsp.config("emmylua_ls", {
    on_init = function(client)
        if is_nvim_config(client.root_dir) then
            client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
                emmylua = { workspace = { library = nvim_lua_library() } },
            })
            client:notify("workspace/didChangeConfiguration", { settings = client.settings })
        end
    end,
})

-- A project's own config file wins; without one, the user-level config in $XDG_CONFIG_HOME is used
local config_home = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
local function user_config(root_dir, project_files, user_file)
    for _, name in ipairs(project_files) do
        if root_dir and vim.uv.fs_stat(vim.fs.joinpath(root_dir, name)) then
            return nil
        end
    end
    local path = vim.fs.joinpath(config_home, user_file)
    return vim.uv.fs_stat(path) and path or nil
end

-- biome: lint + format for json, css, js/ts, html, graphql, ... nvim-lspconfig only starts it in projects with a
-- biome.json, so start it everywhere (root: the project, else the file's directory). Without a project biome.json the
-- user-level ~/.config/biome/biome.json is used (line width 120, spaces).
vim.lsp.config("biome", {
    workspace_required = false,
    root_dir = function(bufnr, on_dir)
        local markers = { "biome.json", "biome.jsonc", "package.json", ".git" }
        on_dir(vim.fs.root(bufnr, markers) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
    end,
    before_init = function(_, config)
        local path = user_config(config.root_dir, { "biome.json", "biome.jsonc" }, "biome/biome.json")
        config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
            biome = { configurationPath = path, requireConfiguration = false },
        })
    end,
})

-- sqruff: SQL lint + format (a Rust rewrite of sqlfluff, same rules). Its language server takes no settings (and ignores
-- --config): it only reads a config file in its workspace root. So a project with its own sqruff config is the root;
-- otherwise it's ~/.config/sqruff, which holds the user config (postgres, line length 120; sqruff's own defaults are
-- ansi and 80). The `sqruff` function in .zshrc uses the same file on the command line.
local function sqruff_project_root(bufnr)
    local root = vim.fs.root(bufnr, { ".sqruff", ".sqruff.ini", "sqruff.toml", ".sqlfluff" })
    if root then
        return root
    end
    local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
    local pyproject = vim.fs.find("pyproject.toml", { path = dir, upward = true })[1]
    if
        pyproject
        and vim.iter(io.lines(pyproject)):any(function(line)
            return vim.startswith(line, "[tool.sqruff")
        end)
    then
        return vim.fs.dirname(pyproject)
    end
end
vim.lsp.config("sqruff", {
    root_dir = function(bufnr, on_dir)
        local user_dir = vim.fs.joinpath(config_home, "sqruff")
        local root = sqruff_project_root(bufnr)
        if not root and vim.uv.fs_stat(vim.fs.joinpath(user_dir, ".sqruff")) then
            root = user_dir
        end
        -- no root at all (no user config either): sqruff runs with its defaults
        on_dir(root or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
    end,
})

-- harper: grammar, in Australian English (its SpellCheck is off: typos_lsp checks spelling). In code it only checks
-- comments, in prose the whole text. Personal words go in ~/.config/harper-ls/dictionary.txt (or its "add to dictionary"
-- code action, `gra`).
-- Filetypes: every language harper-ls supports (https://writewithharper.com/docs/integrations/language-server),
-- by their nvim filetype names; get_language_id maps the ones whose LSP language id differs.
local harper_language_ids = {
    cs = "csharp",
    sh = "shellscript",
    bash = "shellscript",
    zsh = "shellscript",
    ps1 = "powershell",
    text = "plaintext",
    lhaskell = "literate haskell",
}
vim.lsp.config("harper_ls", {
    -- stylua: ignore
    filetypes = {
        "asciidoc", "bash", "c", "clojure", "cmake", "cpp", "cs", "dart", "elixir", "gitcommit", "gleam", "go",
        "groovy", "haskell", "html", "java", "javascript", "javascriptreact", "jjdescription", "kotlin",
        "lhaskell", "lua", "mail", "markdown", "nix", "org", "php", "plaintex", "ps1", "python", "ruby", "rust", "scala",
        "sh", "solidity", "swift", "tex", "text", "toml", "typescript", "typescriptreact", "typst", "zig", "zsh",
    },
    get_language_id = function(_, filetype)
        return harper_language_ids[filetype] or filetype
    end,
    settings = {
        ["harper-ls"] = {
            dialect = "Australian",
            userDictPath = vim.fs.joinpath(config_home, "harper-ls/dictionary.txt"),
            -- spelling is left to typos_lsp: harper's SpellCheck flags every tool name, code and identifier
            linters = { SpellCheck = false },
        },
    },
})

-- terraform-ls: completion, hover, syntax checks for .tf (tflint lints them, see lint_format.lua). It logs every request
-- to stderr, which nvim keeps in lsp.log as errors, so its own log goes nowhere. No "single file" warning for a .tf
-- outside a project. (Its formatting runs the terraform CLI, which isn't installed: see the format on save above.)
vim.lsp.config("terraformls", {
    cmd = { "terraform-ls", "serve", "-log-file=/dev/null" },
    init_options = { ignoreSingleFileWarning = true },
})

-- html: it formats html (biome doesn't by default, see the format on save above). Its defaults differ from biome's and
-- prettier's: <head> and <body> not indented inside <html>, and a blank line added around them. Match those instead.
vim.lsp.config("html", {
    settings = { html = { format = { indentInnerHtml = true, extraLiners = "" } } },
})

-- yamlls: only the plain yaml filetype. nvim-lspconfig also lists yaml.docker-compose, yaml.gitlab and yaml.helm-values,
-- which nvim never sets (:checkhealth vim.lsp warns about them); the schemas for those files are picked by file name.
vim.lsp.config("yamlls", { filetypes = { "yaml" } })

-- jinja-lsp only attaches to the "jinja" filetype, which nvim doesn't detect from these extensions on its own
vim.filetype.add({ extension = { jinja = "jinja", jinja2 = "jinja", j2 = "jinja" } })

-- Default cmd/filetypes/root_markers come from nvim-lspconfig's lsp/*.lua
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
