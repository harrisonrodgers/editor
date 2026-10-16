-- ty: let it watch the project's files, so a change made outside nvim (by Claude, git, a formatter) to a file that isn't
-- open updates the errors in the files that are (e.g. a changed function signature). nvim only offers file watching on
-- Linux when asked: it watches the whole project with inotifywait (inotify-tools, see the Dockerfile), so only ty has it.
---@type vim.lsp.Config
return {
    capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } },
}
