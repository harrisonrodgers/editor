-- Autocmds that aren't tied to one feature's config file

-- Linewise visual mode (V): highlight the whole width of the selected lines, not just up to the end of the text.
-- nvim has no option for this, so while in V mode the selected lines get a Visual-colored extmark that reaches the edge.
do
    local ns = vim.api.nvim_create_namespace("linewise_visual")
    local function clear(buf)
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
    local function update()
        local buf = vim.api.nvim_get_current_buf()
        clear(buf)
        if vim.fn.mode() ~= "V" then
            return
        end
        local first, last = vim.fn.line("v"), vim.fn.line(".")
        if first > last then
            first, last = last, first
        end
        vim.api.nvim_buf_set_extmark(
            buf,
            ns,
            first - 1,
            0,
            { end_row = last, end_col = 0, hl_group = "Visual", hl_eol = true }
        )
    end
    vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved" }, {
        callback = function(ev)
            local event = vim.v.event --[[@as { new_mode: string, old_mode: string }]] -- set during ModeChanged
            if ev.event == "ModeChanged" and not event.new_mode:match("^V") and not event.old_mode:match("^V") then
                return
            end
            update()
        end,
    })
end

-- Open a file at the cursor position it had when last closed (the '" mark). Not for git's commit message / rebase todo
-- buffers: they are new text each time, so start at the top.
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function(ev)
        -- 'filetype' isn't set yet: this autocmd runs before nvim's filetype detection (enabled after init.lua)
        local filetype = vim.filetype.match({ buf = ev.buf }) or ""
        if vim.tbl_contains({ "gitcommit", "gitrebase", "jjdescription" }, filetype) then
            return
        end
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        if mark[1] >= 1 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- Eager autoreload if file changed on disk (e.g. auto-formatter, auto-linter, LLM)
vim.cmd([[autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() != 'c' | checktime | endif]])
