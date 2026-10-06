-- Tools that don't have a language server: nvim-lint for diagnostics, conform for formatting

-- nvim-lint has no built-in xmllint linter, so define one: `xmllint --noout -` reads stdin and reports problems on stderr as
--   -:2: parser error : Opening and ending tag mismatch: b line 2 and a
-- (the lines that follow, with the source line and a ^, don't match the pattern and are skipped)
require("lint").linters.xmllint = {
	cmd = "xmllint",
	stdin = true,
	stream = "stderr",
	args = { "--noout", "-" },
	ignore_exitcode = true,
	parser = require("lint.parser").from_pattern("^%-:(%d+): ([%w ]+) : (.+)$", { "lnum", "severity", "message" }, {
		["parser error"] = vim.diagnostic.severity.ERROR,
		["validity error"] = vim.diagnostic.severity.ERROR,
		["namespace error"] = vim.diagnostic.severity.ERROR,
		["warning"] = vim.diagnostic.severity.WARN,
	}, { source = "xmllint" }),
}

require("lint").linters_by_ft = {
	gitcommit = { "gitlint" },
	yaml = { "yamllint" },
	markdown = { "markdownlint-cli2" },
	dockerfile = { "hadolint" },
	terraform = { "tflint" },
	sql = { "sqlfluff" },
	proto = { "buf_lint" },
	xml = { "xmllint" },
}

-- FileType as well as BufReadPost: when a file is opened, BufReadPost can run before its filetype is detected, and
-- then there is no linter to pick, so the first diagnostics would only appear after the first write
vim.api.nvim_create_autocmd({ "FileType", "BufReadPost", "BufWritePost", "InsertLeave" }, {
	callback = function() require("lint").try_lint() end,
})

require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		-- Only the repo's ruff config applies here (nvim's extra lint rules in lsp.lua are not used): safe auto-fixes of
		-- the repo's rules (this also sorts imports if the repo selects "I"). The formatting itself is done by the ruff
		-- language server, see the format on save in lsp.lua.
		python = { "ruff_fix" },
		sh = { "shfmt" },
		bash = { "shfmt" },
		markdown = { "markdownlint-cli2" }, -- runs `markdownlint-cli2 --fix`
		proto = { "buf" },
		xml = { "xmllint" },
		sql = { "sqlfluff" },
	},
	formatters = {
		-- sqlfluff needs a dialect; default to postgres and don't require a .sqlfluff project root
		sqlfluff = { require_cwd = false, args = { "fix", "--dialect", "postgres", "-" } },
	},
	format_on_save = { timeout_ms = 2000, lsp_format = "never" },
})
