-- html: it formats html (biome doesn't by default, see the format on save in lua/config/lsp.lua). Its defaults differ
-- from biome's and prettier's: <head> and <body> not indented inside <html>, and a blank line added around them. Match
-- those instead.
---@type vim.lsp.Config
return {
    settings = { html = { format = { indentInnerHtml = true, extraLiners = "" } } },
}
