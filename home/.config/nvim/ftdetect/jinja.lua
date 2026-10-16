-- jinja-lsp only attaches to the "jinja" filetype, which nvim doesn't detect from these extensions on its own
vim.filetype.add({ extension = { jinja = "jinja", jinja2 = "jinja", j2 = "jinja" } })
