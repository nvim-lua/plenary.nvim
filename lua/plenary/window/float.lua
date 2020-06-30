package.loaded['plenary.tbl'] = nil
package.loaded['plenary.window.float'] = nil

local Border = require("plenary.window.border")
local tbl = require('plenary.tbl')

_associated_bufs = {}

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

function win_float.centered_with_top_win(top_text, options)
  options = tbl.apply_defaults(options, win_float.default_options)

  table.insert(top_text, 1, string.rep("=", 80))
  table.insert(top_text, string.rep("=", 80))

  local primary_win_opts = win_float.default_opts(options)
  local minor_win_opts = vim.deepcopy(primary_win_opts)

  primary_win_opts.height = primary_win_opts.height - #top_text - 1
  primary_win_opts.row = primary_win_opts.row + #top_text + 1

  minor_win_opts.height = #top_text

  local minor_buf = vim.fn.nvim_create_buf(false, true)
  local minor_win = vim.fn.nvim_open_win(minor_buf, true, minor_win_opts)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(minor_win, 'winblend', options.winblend)

  vim.api.nvim_buf_set_lines(minor_buf, 0, -1, false, top_text)

  local primary_buf = vim.fn.nvim_create_buf(false, true)
  local primary_win = vim.fn.nvim_open_win(primary_buf, true, primary_win_opts)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(primary_win, 'winblend', options.winblend)

  -- vim.cmd(
  --   string.format(
  --     "autocmd WinLeave,BufDelete,BufLeave <buffer=%s> ++once ++nested silent! execute 'bdelete! %s'",
  --     primary_buf,
  --     minor_buf
  --   )
  -- )

  -- vim.cmd(
  --   string.format(
  --     "autocmd WinLeave,BufDelete,BufLeave <buffer> ++once ++nested silent! execute 'bdelete! %s'",
  --     primary_buf
  --   )
  -- )


  local primary_border = Border:new(primary_buf, primary_win, primary_win_opts, {})
  local minor_border = Border:new(minor_buf, minor_win, minor_win_opts, {})

  _associated_bufs[primary_buf] = {
    primary_win, minor_win, primary_border.win_id, minor_border.win_id
  }

  vim.cmd(
    string.format(
      "autocmd WinLeave,BufLeave,BufDelete <buffer=%s> ++once ++nested lua require('plenary.window.float').clear(%s)",
      primary_buf,
      primary_buf
    )
  )

  return {
    buf = primary_buf,
    win = primary_win,

    minor_buf = minor_buf,
    minor_win = minor_win,
  }
end

win_float.clear = function(bufnr)
  if _associated_bufs[bufnr] == nil then
    return
  end

  for _, win_id in ipairs(_associated_bufs[bufnr]) do
    if vim.api.nvim_win_is_valid(win_id) then
      vim.fn.nvim_win_close(win_id, true)
    end
  end

  _associated_bufs[bufnr] = nil
end

return win_float
