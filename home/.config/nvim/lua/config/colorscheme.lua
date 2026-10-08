vim.opt.termguicolors = true
vim.opt.background = "light"
vim.cmd([[colorscheme selenized]])

-- Lighten the theme's bg_1 (used for the cursor line, popup menu, etc.). The theme builds its palette internally, so
-- swap the color in every highlight group that uses it, and in the palette table other config files read from.
do
    ---@diagnostic disable-next-line: undefined-field -- _G.selenized is set by the selenized.nvim theme at runtime
    local c = _G.selenized.colors
    local old_bg_1 = tonumber(c.bg_1:sub(2), 16)
    c.bg_1 = "#f2ecd6" -- theme default for light is #e9e4d0
    local new_bg_1 = tonumber(c.bg_1:sub(2), 16)
    for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
        if not hl.link then
            local changed = false
            for _, key in ipairs({ "fg", "bg", "sp" }) do
                if hl[key] == old_bg_1 then
                    hl[key] = new_bg_1
                    changed = true
                end
            end
            if changed then
                vim.api.nvim_set_hl(0, name, hl)
            end
        end
    end
end

-- Ensure comments are always italic
vim.cmd([[highlight Comment gui=italic]])

-- TODO: figure out how to set just the italic field without resetting the rest of the settings (e.g. the theme's color)
--vim.api.nvim_set_hl(0, "Comment", { italic = true })

-- Bold the line number of the cursor line (`highlight` only changes gui, so the theme's colors are kept)
vim.cmd([[highlight CursorLineNr gui=bold]])

---@diagnostic disable-next-line: undefined-field -- _G.selenized is set by the selenized.nvim theme at runtime
local c = _G.selenized.colors -- the theme's palette (with bg_1 lightened above), used by the groups below

-- Border of floating windows (diagnostics, hover, ...): the theme's bg_1-colored border is almost invisible against the
-- float background, so use the comment color, the same as the completion menu border (PmenuBorder)
vim.api.nvim_set_hl(0, "FloatBorder", { fg = c.dim_0, bg = c.bg_0 })

-- Completion popup menu: same background as floats (the theme uses the darker bg_1). Its border, kind and extra columns
-- inherit from Pmenu; the selected item keeps the theme's PmenuSel background.
vim.api.nvim_set_hl(0, "Pmenu", { fg = c.dim_0, bg = c.bg_0 })

-- Inlay hints: the theme leaves them unstyled (so they look like normal code). Make them a faint version of the comment
-- color, blended toward the background; raise the 0.5 for more contrast, lower it to fade them further.
-- (bg_0 itself would be invisible: it is the editor background.)
vim.api.nvim_set_hl(0, "LspInlayHint", { fg = require("config/tint")(c.dim_0, c.bg_0, 0.5) })

-- Completion menu: color of the "kind" column per LSP completion item kind (see completion_convert in lsp.lua)
local kind_colors = {
    Function = c.blue,
    Method = c.blue,
    Constructor = c.blue,
    Class = c.yellow,
    Interface = c.yellow,
    Struct = c.yellow,
    Enum = c.yellow,
    TypeParameter = c.yellow,
    Variable = c.cyan,
    Field = c.cyan,
    Property = c.cyan,
    Constant = c.orange,
    Value = c.orange,
    EnumMember = c.orange,
    Unit = c.orange,
    Module = c.violet,
    File = c.violet,
    Folder = c.violet,
    Reference = c.violet,
    Keyword = c.magenta,
    Operator = c.magenta,
    Snippet = c.green,
    Text = c.dim_0,
    Color = c.dim_0,
    Event = c.dim_0,
    Unknown = c.dim_0,
}
for kind, color in pairs(kind_colors) do
    vim.api.nvim_set_hl(0, "CompletionKind" .. kind, { fg = color })
end
