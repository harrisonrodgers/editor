-- See `:help vim.diagnostic.*` for documentation on any of the below functions.

-- same look as null-ls' diagnostics_format: [source] (code) message, leaving out "(code)" when there is none
local function format(d)
    local code = (d.code ~= nil and d.code ~= "") and string.format(" (%s)", d.code) or ""
    return string.format("[%s]%s %s", d.source or "?", code, d.message)
end

local virtual_text = {
    format = format,
    -- one letter per severity instead of the default "■" (severity: 1=Error, 2=Warn, 3=Info, 4=Hint)
    prefix = function(d)
        return ({ "E", "W", "I", "H" })[d.severity]
    end,
}

vim.diagnostic.config({
    virtual_text = virtual_text,
    -- suffix = "" stops the float from appending the code a second time ([F401])
    float = { format = format, suffix = "" },
    signs = true,
    underline = false,
    update_in_insert = true,
    severity_sort = true,
})

-- Hide the virtual text while in insert mode (the diagnostics themselves keep updating, see update_in_insert)
-- vim.api.nvim_create_autocmd("InsertEnter", {
-- 	callback = function()
-- 		vim.diagnostic.config({ virtual_text = false })
-- 	end,
-- })
-- vim.api.nvim_create_autocmd("InsertLeave", {
-- 	callback = function()
-- 		vim.diagnostic.config({ virtual_text = virtual_text })
-- 	end,
-- })

-- Diagnostics in a telescope picker: <C-w>D for this buffer (next to nvim's <C-w>d float for the cursor), <space>Q for
-- every open buffer. Telescope's entries only carry the message and the code, so the entry maker looks up the matching
-- vim.diagnostic to get its source and shows the same "[source] (code) message" as the virtual text and the float.
local function diagnostics_picker(opts)
    return function()
        opts = vim.tbl_extend("force", opts, {})
        if opts.bufnr ~= nil then
            opts.path_display = "hidden" -- the file is the current one; telescope does the same for a single buffer
        end
        local default_entry_maker = require("telescope.make_entry").gen_from_diagnostics(opts)
        opts.entry_maker = function(item)
            ---@diagnostic disable-next-line: param-type-mismatch -- lnum is a whole number, emmylua only knows `number`
            for _, d in ipairs(vim.diagnostic.get(item.bufnr, { lnum = item.lnum - 1 })) do
                local message = vim.trim((d.message:gsub("\n", "")))
                if d.col == item.col - 1 and d.code == item.code and message == item.text then
                    item = vim.tbl_extend(
                        "force",
                        item,
                        { text = format({ source = d.source, code = d.code, message = message }) }
                    )
                    break
                end
            end
            return default_entry_maker(item)
        end
        require("telescope.builtin").diagnostics(opts)
    end
end
vim.keymap.set("n", "<C-w>D", diagnostics_picker({ bufnr = 0 }), { silent = true, desc = "Diagnostics of this buffer" })
vim.keymap.set("n", "<space>Q", diagnostics_picker({}), { silent = true, desc = "Diagnostics of all open buffers" })

-- The selenized theme maps DiagnosticWarn to cyan (same as Info) and Hint to yellow, so set our own per-severity colors.
---@diagnostic disable-next-line: undefined-field -- _G.selenized is set by the selenized.nvim theme at runtime
local c = _G.selenized.colors

local tint = require("config/tint")

local severities = {
    Error = c.red,
    Warn = c.orange,
    Info = c.blue,
    Hint = c.green,
}

-- How strongly the virtual text (the text at the end of the line) is drawn: the share of the severity color blended over
-- the editor background, for the text and for its background. Lower = fainter.
local VIRTUAL_TEXT_FG_STRENGTH = 0.65
local VIRTUAL_TEXT_BG_STRENGTH = 0.03

for name, color in pairs(severities) do
    vim.api.nvim_set_hl(0, "Diagnostic" .. name, { fg = color })
    vim.api.nvim_set_hl(0, "DiagnosticUnderline" .. name, { underline = true, sp = color })
    -- Tinted background on the diagnostic sign (these are the default signs, see `signs` in the config above)
    vim.api.nvim_set_hl(0, "DiagnosticSign" .. name, { bold = true, fg = color, bg = tint(color, c.bg_0, 0.2) })
    -- Neovim highlights the virtual text prefix and message with the same group, so the background covers both
    vim.api.nvim_set_hl(0, "DiagnosticVirtualText" .. name, {
        fg = tint(color, c.bg_0, VIRTUAL_TEXT_FG_STRENGTH),
        bg = tint(color, c.bg_0, VIRTUAL_TEXT_BG_STRENGTH),
    })
end
