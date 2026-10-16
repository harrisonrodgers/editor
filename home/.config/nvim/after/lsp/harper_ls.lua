-- harper: grammar, in Australian English (its SpellCheck is off: typos_lsp checks spelling). In code it only checks
-- comments, in prose the whole text. Personal words go in ~/.config/harper-ls/dictionary.txt (or its "add to dictionary"
-- code action, `gra`).
-- Filetypes: every language harper-ls supports (https://writewithharper.com/docs/integrations/language-server),
-- by their nvim filetype names; get_language_id maps the ones whose LSP language id differs.
local util = require("config/util")

local harper_language_ids = {
    cs = "csharp",
    sh = "shellscript",
    bash = "shellscript",
    zsh = "shellscript",
    ps1 = "powershell",
    text = "plaintext",
    lhaskell = "literate haskell",
}

---@type vim.lsp.Config
return {
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
            userDictPath = vim.fs.joinpath(util.config_home, "harper-ls/dictionary.txt"),
            -- spelling is left to typos_lsp: harper's SpellCheck flags every tool name, code and identifier
            linters = { SpellCheck = false },
        },
    },
}
