local tbl = require "plenary.tbl"
local strings = require "plenary.strings"

local Border = {}

Border.__index = Border

Border._default_thickness = {
  top = 1,
  right = 1,
  bot = 1,
  left = 1,
}

local calc_left_start = function(title_pos, title_len, total_width)
  if string.find(title_pos, "W") then
    return 0
  elseif string.find(title_pos, "E") then
    return total_width - title_len
  else
    return math.floor((total_width - title_len) / 2)
  end
end

local create_horizontal_line = function(title, pos, width, left_char, mid_char, right_char)
  local title_len
  if title == "" then
    title_len = 0
  else
    local len = strings.strdisplaywidth(title)
    local max_title_width = width - 2
    if len > max_title_width then
      title = strings.truncate(title, max_title_width)
      len = strings.strdisplaywidth(title)
    end
    title = string.format(" %s ", title)
    title_len = len + 2
  end

  local left_start = calc_left_start(pos, title_len, width)

  local horizontal_line = string.format(
    "%s%s%s%s%s",
    left_char,
    string.rep(mid_char, left_start),
    title,
    string.rep(mid_char, width - title_len - left_start),
    right_char
  )
  return horizontal_line
end

function Border._create_lines(content_win_options, border_win_options)
  -- TODO: Handle border width, which I haven't right here.
  local thickness = border_win_options.border_thickness

  local top_enabled = thickness.top == 1
  local right_enabled = thickness.right == 1
  local bot_enabled = thickness.bot == 1
  local left_enabled = thickness.left == 1

  local border_lines = {}

  local topline = nil

  local topleft = (left_enabled and border_win_options.topleft) or ""
  local topright = (right_enabled and border_win_options.topright) or ""

  -- border_win_options.title should have be a list with entries of the
  -- form: { pos = foo, text = bar }.
  -- pos can take values in { "NW", "N", "NE", "SW", "S", "SE" }
  local titles = type(border_win_options.title) == "string" and { { pos = "N", text = border_win_options.title } }
    or border_win_options.title
    or {}

  if content_win_options.row > 0 then
    for _, title in ipairs(titles) do
      if string.find(title.pos, "N") then
        topline = create_horizontal_line(
          title.text,
          title.pos,
          content_win_options.width,
          topleft,
          border_win_options.top or "",
          topright
        )
        break
      end
    end
    if topline == nil then
      if top_enabled then
        topline = topleft .. string.rep(border_win_options.top, content_win_options.width) .. topright
      end
    end
  end

  if topline then
    table.insert(border_lines, topline)
  end

  local middle_line = string.format(
    "%s%s%s",
    (left_enabled and border_win_options.left) or "",
    string.rep(" ", content_win_options.width),
    (right_enabled and border_win_options.right) or ""
  )

  for _ = 1, content_win_options.height do
    table.insert(border_lines, middle_line)
  end

  if bot_enabled then
    local botline = nil
    local botleft = (left_enabled and border_win_options.botleft) or ""
    local botright = (right_enabled and border_win_options.botright) or ""
    for _, title in ipairs(titles) do
      if string.find(title.pos, "S") then
        botline = create_horizontal_line(
          title.text,
          title.pos,
          content_win_options.width,
          botleft,
          border_win_options.bot or "",
          botright
        )
        break
      end
    end
    if botline == nil then
      if top_enabled then
        botline = botleft .. string.rep(border_win_options.bot, content_win_options.width) .. botright
      end
    end
    table.insert(border_lines, botline)
  end

  return border_lines
end

function Border:change_title(new_title)
  if self._border_win_options.title == new_title then
    return
  end

  self._border_win_options.title = new_title
  self.contents = Border._create_lines(self.content_win_options, self._border_win_options)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, self.contents)
end

function Border:new(content_bufnr, content_win_id, content_win_options, border_win_options)
  assert(type(content_win_id) == "number", "Must supply a valid win_id. It's possible you forgot to call with ':'")

  -- TODO: Probably can use just deep_extend, now that it's available
  border_win_options = tbl.apply_defaults(border_win_options, {
    border_thickness = Border._default_thickness,

    -- Border options, could be passed as a list?
    topleft = "╔",
    topright = "╗",
    top = "═",
    left = "║",
    right = "║",
    botleft = "╚",
    botright = "╝",
    bot = "═",
  })

  local obj = {}

  obj.content_win_id = content_win_id
  obj.content_win_options = content_win_options
  obj._border_win_options = border_win_options

  obj.bufnr = vim.api.nvim_create_buf(false, true)
  assert(obj.bufnr, "Failed to create border buffer")
  vim.api.nvim_buf_set_option(obj.bufnr, "bufhidden", "wipe")

  obj.contents = Border._create_lines(content_win_options, border_win_options)
  vim.api.nvim_buf_set_lines(obj.bufnr, 0, -1, false, obj.contents)

  local thickness = border_win_options.border_thickness

  obj.win_id = vim.api.nvim_open_win(obj.bufnr, false, {
    anchor = content_win_options.anchor,
    relative = content_win_options.relative,
    style = "minimal",
    row = content_win_options.row - thickness.top,
    col = content_win_options.col - thickness.left,
    width = content_win_options.width + thickness.left + thickness.right,
    height = content_win_options.height + thickness.top + thickness.bot,
    zindex = content_win_options.zindex or 50,
    noautocmd = content_win_options.noautocmd,
    focusable = vim.F.if_nil(border_win_options.focusable, false),
  })

  vim.cmd(
    string.format(
      "autocmd BufDelete <buffer=%s> ++nested ++once :lua require('plenary.window').close_related_win(%s, %s)",
      content_bufnr,
      content_win_id,
      obj.win_id
    )
  )

  vim.cmd(
    string.format(
      "autocmd WinClosed <buffer=%s> ++nested ++once :lua require('plenary.window').try_close(%s, true)",
      content_bufnr,
      obj.win_id
    )
  )

  setmetatable(obj, Border)

  return obj
end

return Border
