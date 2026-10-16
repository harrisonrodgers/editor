-- terraform-ls: completion, hover, syntax checks for .tf (tflint lints them, see lua/config/lint/tflint.lua). It logs
-- every request to stderr, which nvim keeps in lsp.log as errors, so its own log goes nowhere. No "single file" warning
-- for a .tf outside a project. (Its formatting runs the terraform CLI, which isn't installed: see the format on save in
-- lua/config/lsp.lua.)
---@type vim.lsp.Config
return {
    cmd = { "terraform-ls", "serve", "-log-file=/dev/null" },
    init_options = { ignoreSingleFileWarning = true },
}
