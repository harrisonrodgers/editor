-- Shrink quickfix/location list windows to fit their entries (max 10 lines) instead of always using 10 lines.
-- Scheduled so the height is measured after the command that opened the window (e.g. :DiffTool) has filled the list.
local buf = vim.api.nvim_get_current_buf()
vim.schedule(function()
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then
        local lines = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_win_set_height(win, math.max(1, math.min(lines, 10)))
    end
end)
