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

-- lsp.lua's LspAttach passes this to vim.lsp.completion.enable for each server
return { convert = completion_convert }
