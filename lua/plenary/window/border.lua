package.loaded['plenary.window.border'] = nil

local tbl = require('plenary.tbl')

local Border = {}

Border.__index = Border

function Border._create_lines(content_win_options, border_win_options)
  -- TODO: Handle border width, which I haven't right here.
  local topline
  if border_win_options.title then
    local title = string.format(" %s ", border_win_options.title)
    local title_len = string.len(title)

    local midpoint = math.floor(content_win_options.width / 2)
    local left_start = midpoint - math.floor(title_len / 2)

    topline = string.format("%s%s%s%s%s",
      border_win_options.topleft,
      string.rep(border_win_options.top, left_start),
      title,
      string.rep(border_win_options.top, content_win_options.width - title_len - left_start),
      border_win_options.topright
    )
  else
    topline = border_win_options.topleft
      .. string.rep(border_win_options.top, content_win_options.width)
      .. border_win_options.topright
  end

  local border_lines = { topline }

  local middle_line = (
    border_win_options.left
    .. string.rep(' ', content_win_options.width)
    .. border_win_options.right
  )

  for _ = 1, content_win_options.height do
    table.insert(border_lines, middle_line)
  end

  table.insert(border_lines,
    border_win_options.botleft
    .. string.rep('═', content_win_options.width)
    .. border_win_options.botright
  )

  return border_lines
end

function Border:new(content_buf_id, content_win_id, content_win_options, border_win_options)
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


  obj.buf_id = vim.api.nvim_create_buf(false, true)
  assert(obj.buf_id, "Failed to create border buffer")

  obj.contents = Border._create_lines(content_win_options, border_win_options)
  vim.api.nvim_buf_set_lines(obj.buf_id, 0, -1, false, obj.contents)

  local border_width = border_win_options.width

  obj.win_id = vim.api.nvim_open_win(obj.buf_id, false, {
    relative = content_win_options.relative,
    style = "minimal",
    row = content_win_options.row - border_width,
    col = content_win_options.col - border_width,
    width = content_win_options.width + 2 * border_width,
    height = content_win_options.height + 2 * border_width,
  })

  vim.cmd(
    string.format(
      "autocmd BufLeave,BufDelete <buffer=%s> ++once call nvim_win_close(%s, v:false)",
      content_buf_id,
      obj.win_id
    )
  )

  setmetatable(obj, Border)

  return obj
end


return Border
