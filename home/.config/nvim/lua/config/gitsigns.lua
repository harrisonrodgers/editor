-- Configure gitsigns (https://github.com/lewis6991/gitsigns.nvim)
---@diagnostic disable-next-line: undefined-field -- _G.selenized is set by the selenized.nvim theme at runtime
local c = _G.selenized.colors
local tint = require("config/tint")

-- The signs are blank cells with a colored background. Staged hunks (already `git add`ed) get a fainter version of the
-- same color. Set before setup(): gitsigns derives the groups that aren't set (number column, line, cursor line, ...)
-- from these when it starts.
local colors = { Add = "#E2E9C1", Change = "#DDE4F2", Delete = "#F7E0C3" }
local STAGED_STRENGTH = 0.5 -- share of the color blended over the editor background for staged hunks
for kind, color in pairs(colors) do
    vim.api.nvim_set_hl(0, "GitSigns" .. kind, { bg = color })
    vim.api.nvim_set_hl(0, "GitSignsStaged" .. kind, { bg = tint(color, c.bg_0, STAGED_STRENGTH) })
end
-- a changed line followed by deleted ones, and lines deleted at the top of the file: shown as a deletion
for _, prefix in ipairs({ "GitSigns", "GitSignsStaged" }) do
    vim.api.nvim_set_hl(0, prefix .. "Changedelete", { link = prefix .. "Delete" })
    vim.api.nvim_set_hl(0, prefix .. "Topdelete", { link = prefix .. "Delete" })
end

local blank = {
    add = { text = " " },
    change = { text = " " },
    delete = { text = " " },
    topdelete = { text = " " },
    changedelete = { text = " " },
}

require("gitsigns").setup({
    signs = blank,
    signs_staged = blank, -- without this, staged hunks show gitsigns' default "┃" signs
    -- keys (listed on the start screen, start_screen.lua)
    on_attach = function(bufnr)
        local gitsigns = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { silent = true, buffer = bufnr, desc = desc })
        end
        map("n", "gb", function()
            gitsigns.blame_line({ full = true })
        end, "Blame the line (full commit message)")
        map("n", "]h", function()
            gitsigns.nav_hunk("next")
        end, "Next git hunk")
        map("n", "[h", function()
            gitsigns.nav_hunk("prev")
        end, "Previous git hunk")
        map("n", "<space>hp", gitsigns.preview_hunk, "Preview the hunk (the diff in a float)")
        map("n", "<space>hs", gitsigns.stage_hunk, "Stage / unstage the hunk")
        map("n", "<space>hr", gitsigns.reset_hunk, "Reset the hunk (discard the change)")
        -- in visual mode: only the selected lines
        map("v", "<space>hs", function()
            gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage / unstage the selected lines")
        map("v", "<space>hr", function()
            gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset the selected lines")
        map("n", "<space>hd", gitsigns.diffthis, "Diff the file against the index")
    end,
})
