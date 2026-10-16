-- yamlls: only the plain yaml filetype. nvim-lspconfig also lists yaml.docker-compose, yaml.gitlab and yaml.helm-values,
-- which nvim never sets (:checkhealth vim.lsp warns about them); the schemas for those files are picked by file name.
---@type vim.lsp.Config
return { filetypes = { "yaml" } }
