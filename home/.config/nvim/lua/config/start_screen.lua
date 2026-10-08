-- Custom start screen, shown when nvim is started without a file: a cheat sheet of the keys this setup uses, LSP first,
-- then diagnostics, then telescope. It is plain text, so keep it in sync by hand when the keys change
-- (lsp.lua, diagnostic.lua; the telescope in-picker keys are telescope's own defaults).

-- The descriptions are at most 42 characters: two columns have to fit in 120 terminal columns.
local sections = {
    {
        title = "LSP",
        note = "in a buffer with a language server attached",
        items = {
            { "gd", "definition" },
            { "gD", "declaration" },
            { "grr", "references" },
            { "gri", "implementation" },
            { "grt", "type definition" },
            { "grn", "rename" },
            { "gra", "code action (also in visual mode)" },
            { "grx", "run the code lens on this line" },
            { "gO", "symbols in this file" },
            { "grs", "symbols in the whole project" },
            { "grc", "callers of the symbol" },
            { "grC", "callees of the symbol" },
            { "grh", "subtypes: classes inheriting from this" },
            { "grH", "supertypes: classes this one inherits from" },
            { "K", "hover docs" },
            { "<C-s>", "signature help (insert mode)" },
            { "<space>wa", "add a workspace folder" },
            { "<space>wr", "remove a workspace folder" },
            { "<space>wl", "list workspace folders" },
        },
    },
    {
        title = "Diagnostics",
        items = {
            { "]d", "next diagnostic" },
            { "[d", "previous diagnostic" },
            { "]D", "last diagnostic in the buffer" },
            { "[D", "first diagnostic in the buffer" },
            { "<C-w>d", "float with the diagnostics at the cursor" },
            { "<C-w>D", "diagnostics of this buffer" },
            { "<space>Q", "diagnostics of all open buffers" },
        },
    },
    {
        title = "Telescope",
        note = "these are also the pickers behind: gd grr gri grt gO grs grc grC <C-w>D <space>Q",
        items = {
            { "<space>ff", "find files" },
            { "<space>fg", "live grep" },
            { "<space>fof", "recently opened files" },
            { "<space>fmp", "man pages" },
        },
    },
    {
        title = "In a telescope picker",
        items = {
            { "<C-n> <C-p>", "move down / up (or the arrow keys)" },
            { "<CR>", "open the selection" },
            { "<C-x>", "open in a horizontal split" },
            { "<C-v>", "open in a vertical split" },
            { "<C-t>", "open in a new tab" },
            { "<Tab>", "mark / unmark the entry" },
            { "<C-q>", "send all entries to the quickfix list" },
            { "<M-q>", "send marked entries to the quickfix list" },
            { "<C-u> <C-d>", "scroll the preview up / down" },
            { "<C-/>", "show every key of the picker" },
            { "<C-c>", "close" },
        },
    },
}

local KEY_WIDTH = 12 -- room for the longest key, "<C-n> <C-p>"
local COLUMN_WIDTH = 60 -- one column: indent + key + description

local function render()
    local lines, marks = { "" }, {} -- marks: { line index (0-based), col start, col end, highlight group }
    local function add(text)
        lines[#lines + 1] = text
        return #lines - 1
    end
    -- same as the first line of `nvim --version`, e.g. "NVIM v0.12.5"
    local v = vim.version()
    local heading = ("  NVIM v%d.%d.%d"):format(v.major, v.minor, v.patch)
        .. (v.prerelease and ("-" .. v.prerelease) or "")
        .. (type(v.build) == "string" and ("+" .. v.build) or "")
    marks[#marks + 1] = { add(heading), 0, #heading, "Title" }
    for _, section in ipairs(sections) do
        add("")
        local row = add("  " .. section.title .. (section.note and ("  " .. section.note) or ""))
        marks[#marks + 1] = { row, 0, 2 + #section.title, "Title" }
        if section.note then
            marks[#marks + 1] = { row, 2 + #section.title, #lines[#lines], "Comment" }
        end
        -- two columns, filled top to bottom: the first half of the items on the left, the rest on the right
        local rows = math.ceil(#section.items / 2)
        for r = 1, rows do
            local text = ""
            local line_marks = {}
            for c = 0, 1 do
                local item = section.items[r + c * rows]
                if item then
                    local start = c * COLUMN_WIDTH
                    local cell = "    " .. item[1]
                    cell = cell .. string.rep(" ", math.max(1, 4 + KEY_WIDTH - #cell)) .. item[2]
                    text = text .. string.rep(" ", start - #text) .. cell
                    line_marks[#line_marks + 1] = { start + 4, start + 4 + #item[1] }
                end
            end
            local line = add(text)
            for _, m in ipairs(line_marks) do
                marks[#marks + 1] = { line, m[1], m[2], "Special" }
            end
        end
    end
    add("")
    local footer = add("  :e <file> to edit     :help lsp-defaults     :checkhealth vim.lsp")
    marks[#marks + 1] = { footer, 0, #lines[#lines], "Comment" }
    return lines, marks
end

vim.opt.shortmess:append("I") -- hide nvim's built-in intro message, this screen replaces it

vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        -- only for a plain `nvim`: no file arguments, nothing read from stdin, an empty unnamed buffer
        if
            vim.fn.argc() ~= 0
            or vim.api.nvim_buf_get_name(buf) ~= ""
            or vim.bo[buf].modified
            or vim.api.nvim_buf_line_count(buf) > 1
            or vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= ""
        then
            return
        end

        local lines, marks = render()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local ns = vim.api.nvim_create_namespace("start_screen")
        for _, m in ipairs(marks) do
            vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
        end
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].swapfile = false
        vim.bo[buf].modifiable = false
        vim.bo[buf].modified = false

        -- Window options that would clutter this screen. They belong to the window, so they would carry over to the next
        -- file opened in it: put them back when this buffer goes away.
        local win = vim.api.nvim_get_current_win()
        local saved = {}
        for _, option in ipairs({
            "number",
            "relativenumber",
            "cursorline",
            "list",
            "spell",
            "signcolumn",
            "colorcolumn",
        }) do
            saved[option] = vim.wo[win][option]
            vim.wo[win][option] = (option == "signcolumn") and "no" or (option == "colorcolumn") and "" or false
        end
        vim.api.nvim_create_autocmd("BufWinLeave", {
            buffer = buf,
            once = true,
            callback = function()
                for option, value in pairs(saved) do
                    vim.wo[win][option] = value
                end
            end,
        })
    end,
})
