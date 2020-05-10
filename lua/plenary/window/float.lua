package.loaded['plenary.tbl'] = nil
package.loaded['plenary.window.float'] = nil

local tbl = require('plenary.tbl')

local win_float = {}

win_float.default_options = {
  winblend = 15,
  percentage = 0.9,
}

function win_float.default_opts(options)
  options = tbl.apply_defaults(options, win_float.default_options)

  local width = math.floor(vim.o.columns * options.percentage)
  local height = math.floor(vim.o.lines * options.percentage)

  local top = math.floor(((vim.o.lines - height) / 2) - 1)
  local left = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = 'editor',
    row      = top,
    col      = left,
    width    = width,
    height   = height,
    style    = 'minimal'
  }

  return opts
end

function win_float.centered(options)
  options = tbl.apply_defaults(options, win_float.default_options)

  local win_opts = win_float.default_opts(options)

  local buf = vim.fn.nvim_create_buf(false, true)
  local win = vim.fn.nvim_open_win(buf, true, win_opts)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(win, 'winblend', options.winblend)

  vim.cmd(
    string.format(
      "autocmd WinLeave <buffer> silent! execute 'bdelete! %s'",
      buf
    )
  )

  return {
    buf=buf,
    win=win,
  }
end

return win_float
