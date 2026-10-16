-- jsonls sets no `source` on its JSON Schema diagnostics (its syntax ones say "json"), so they show as "[?]". Fill it in,
-- for both ways it sends them: pushed (publishDiagnostics) and pulled by nvim (textDocument/diagnostic).
-- (biome formats json where it's attached, see the format on save in lua/config/lsp.lua)
local function with_json_source(diagnostics)
    for _, d in ipairs(diagnostics or {}) do
        d.source = d.source or "json"
    end
end

---@type vim.lsp.Config
return {
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
}
