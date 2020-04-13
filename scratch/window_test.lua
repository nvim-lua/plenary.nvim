--luacheck: ignore

function CanWinBeHidden()
    -- The answer is yes
    -- Just keep track of the buffer ID

    local what = "test string"
    local buf = vim.fn.nvim_create_buf(false, true)

    -- TODO: Handle list of lines
    vim.fn.nvim_buf_set_lines(buf, 0, -1, true, {what})

    local win = vim.fn.nvim_open_win(buf, true, {relative='win', row=3, col=3, width=40, height=3})
    vim.fn.nvim_win_close(win, false)
end


function CanWinBeReordered()
    what = "test string"
    buf_text = vim.fn.nvim_create_buf(false, true)

    buf_border = vim.fn.nvim_create_buf(false, true)

    -- TODO: Handle list of lines
    vim.fn.nvim_buf_set_lines(buf_text, 0, -1, true, {what})
    vim.fn.nvim_buf_set_lines(buf_border, 0, -1, true, {"====", "", "====="})

    win_text = vim.fn.nvim_open_win(buf_text, false, {relative='win', row=3, col=3, width=40, height=1})
    win_border = vim.fn.nvim_open_win(buf_border, false, {relative='win', row=2, col=3, width=40, height=3})

    vim.fn.nvim_win_close(win_text, false)
    vim.fn.nvim_win_close(win_border, false)

    current_win = vim.fn.win_getid()
    _ = {vim.fn.win_gotoid(win_text), vim.cmd("sleep 100m"), vim.fn.win_gotoid(current_win)}
    _ = {vim.fn.win_gotoid(win_text), vim.cmd("redraw"), vim.fn.win_gotoid(current_win)}
end
