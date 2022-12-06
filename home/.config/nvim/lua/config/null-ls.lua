-- https://github.com/jose-elias-alvarez/null-ls.nvim/wiki/Formatting-on-save
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

-- null-ls for formatting and linting
local null_ls = require("null-ls")
null_ls.setup({
	-- #{m}: message
	-- #{s}: source name (defaults to null-ls if not specified)
	-- #{c}: lint error code (if available)
	diagnostics_format = "[#{s}] (#{c}) #{m}",
	-- you must define at least one source for the plugin to work
	sources = {
		-- MORE: https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md
		-- python
		null_ls.builtins.formatting.black,
		null_ls.builtins.formatting.isort,
		null_ls.builtins.diagnostics.flake8.with({
			args = {
				"--stdin-display-name",
				"$FILENAME",
				"-", -- default args
				"--extend-ignore=A,B,W503,E501,E203,E741",
				-- "--extend-select=RST,D", -- needs flake8 4.0
				"--max-line-length=120",
			},
		}),
		null_ls.builtins.diagnostics.pylint.with({
			args = {
				"--from-stdin",
				"$FILENAME",
				"-f",
				"json", -- default args
				-- W0212: Access to a protected member %s of a client class
				"--disable=W0212",
				--"C0114",
				--"C0115",
				--"C0116",
				--"C0301",
				--"C0411",
				--"C0412",
				--"W1203",
				--"C0330",
				--"W0611",
				--"W0703",
				--"R0903",
			},
		}),
		-- lua
		null_ls.builtins.formatting.stylua,
		null_ls.builtins.diagnostics.luacheck,
		-- json
		null_ls.builtins.formatting.json_tool, -- this is python's built in `json.tool`
		-- gitcommit
		null_ls.builtins.diagnostics.gitlint,
	},
	-- you can reuse a shared lspconfig on_attach callback here
	on_attach = function(client, bufnr)
		if client.supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.format({ bufnr = bufnr })
				end,
			})
		end
	end,
})
