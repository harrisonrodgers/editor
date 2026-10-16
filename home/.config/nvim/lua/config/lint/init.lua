-- nvim-lint: diagnostics from tools that don't have a language server. The linters nvim-lint lacks, or gets wrong, are
-- defined or fixed in the files next to this one.
for _, name in ipairs({ "xmllint", "j2lint", "gitlint", "buf_lint", "tflint" }) do
    require("config/lint/" .. name)
end

require("lint").linters_by_ft = {
    gitcommit = { "gitlint" },
    yaml = { "yamllint" },
    dockerfile = { "hadolint" },
    terraform = { "tflint" },
    proto = { "buf_lint" },
    xml = { "xmllint" },
    jinja = { "j2lint" },
}

-- FileType as well as BufReadPost: when a file is opened, BufReadPost can run before its filetype is detected, and
-- then there is no linter to pick, so the first diagnostics would only appear after the first write
vim.api.nvim_create_autocmd({ "FileType", "BufReadPost", "BufWritePost", "InsertLeave" }, {
    callback = function()
        require("lint").try_lint()
    end,
})
