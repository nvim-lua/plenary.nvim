local tbl = require('plenary.tbl')

local Border = {}

Border.__index = Border

function Border._create_lines(content_win_options)
  -- TODO: Handle border width, which I haven't right here.

  local border_lines = { '╔' .. string.rep('═', content_win_options.width) .. '╗' }

  local middle_line = '║' .. string.rep(' ', content_win_options.width) .. '║'
  for _ = 1, content_win_options.height do
    table.insert(border_lines, middle_line)
  end

  table.insert(border_lines, '╚' .. string.rep('═', content_win_options.width) .. '╝')

  return border_lines
end

function Border:new(content_win_id, content_win_options, border_win_options)
  assert(type(content_win_id) == 'number', "Must supply a valid win_id. It's possible you forgot to call with ':'")

  border_win_options = tbl.apply_defaults(border_win_options, {
    width = 1,

    -- Border options, could be passed as a list?
    topleft  = '╔',
    topright = '╗',
    top      = '═',
    left     = '║',
    right    = '║',
    botleft  = '╚',
    botright = '╝',
    bottom   = '═',
  })

  local obj = {}

  obj.content_win_id = content_win_id
  obj.content_win_options = content_win_options
  obj._border_win_options = border_win_options

  local border_width = border_win_options.width
  obj.width = content_win_options.width + 2 * border_width
  obj.height = content_win_options.height + 2 * border_width

  obj.buf_id = vim.api.nvim_create_buf(false, true)

  obj.contents = Border._create_lines(content_win_options)
  vim.api.nvim_buf_set_lines(obj.buf_id, 0, -1, false, obj.contents)

  obj.style = "minimal"
  obj.relative = content_win_options.relative
  obj.row = content_win_options.row - border_width
  obj.col = content_win_options.col - border_width

  obj.win_id = vim.api.nvim_open_win(obj.buf_id, obj)

  setmetatable(obj, Border)

  return obj
end


return Border
