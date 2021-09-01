--- popup.lua
---
--- Wrapper to make the popup api from vim in neovim.
--- Hope to get this part merged in at some point in the future.
---
--- Please make sure to update "POPUP.md" with any changes and/or notes.

local Border = require "plenary.window.border"
local Window = require "plenary.window"
local utils = require "plenary.popup.utils"

local popup = {}

popup._pos_map = {
  topleft = "NW",
  topright = "NE",
  botleft = "SW",
  botright = "SE",
}

-- Keep track of hidden popups, so we can load them with popup.show()
popup._hidden = {}

local function dict_default(options, key, default)
  if options[key] == nil then
    return default[key]
  else
    return options[key]
  end
end

-- Callbacks to be called later by popup.execute_callback
popup._callbacks = {}

function popup.create(what, vim_options)
  local bufnr
  if type(what) == "number" then
    bufnr = what
  else
    bufnr = vim.api.nvim_create_buf(false, true)
    assert(bufnr, "Failed to create buffer")

    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")

    -- TODO: Handle list of lines
    if type(what) == "string" then
      what = { what }
    else
      assert(type(what) == "table", '"what" must be a table')
    end

    -- padding    List with numbers, defining the padding
    --     above/right/below/left of the popup (similar to CSS).
    --     An empty list uses a padding of 1 all around.  The
    --     padding goes around the text, inside any border.
    --     Padding uses the 'wincolor' highlight.
    --     Example: [1, 2, 1, 3] has 1 line of padding above, 2
    --     columns on the right, 1 line below and 3 columns on
    --     the left.
    if vim_options.padding then
      local pad_top, pad_right, pad_below, pad_left
      if vim.tbl_isempty(vim_options.padding) then
        pad_top = 1
        pad_right = 1
        pad_below = 1
        pad_left = 1
      else
        local padding = vim_options.padding
        pad_top = padding[1] or 0
        pad_right = padding[2] or 0
        pad_below = padding[3] or 0
        pad_left = padding[4] or 0
      end

      local left_padding = string.rep(" ", pad_left)
      local right_padding = string.rep(" ", pad_right)
      for index = 1, #what do
        what[index] = string.format("%s%s%s", left_padding, what[index], right_padding)
      end

      for _ = 1, pad_top do
        table.insert(what, 1, "")
      end

      for _ = 1, pad_below do
        table.insert(what, "")
      end
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, what)
  end

  local option_defaults = {
    posinvert = true,
    zindex = 50,
  }

  local win_opts = {}
  win_opts.relative = "editor"

  local cursor_relative_pos = function(pos_str, dim)
    assert(string.find(pos_str, "^cursor"), "Invalid value for " .. dim)
    win_opts.relative = "cursor"
    local line = 0
    if (pos_str):match "cursor%+(%d+)" then
      line = line + tonumber((pos_str):match "cursor%+(%d+)")
    elseif (pos_str):match "cursor%-(%d+)" then
      line = line - tonumber((pos_str):match "cursor%-(%d+)")
    end
    return line
  end

  if vim_options.line then
    if type(vim_options.line) == "string" then
      win_opts.row = cursor_relative_pos(vim_options.line, "row")
    else
      win_opts.row = vim_options.line
    end
  else
    -- TODO: It says it needs to be "vertically cenetered"?...
    -- wut is that.
    win_opts.row = 0
  end

  if vim_options.col then
    if type(vim_options.col) == "string" then
      win_opts.col = cursor_relative_pos(vim_options.col, "col")
    else
      win_opts.col = vim_options.col
    end
  else
    -- TODO: It says it needs to be "horizontally cenetered"?...
    win_opts.col = 0
  end

  if vim_options.pos then
    if vim_options.pos == "center" then
      -- TODO: Do centering..
    else
      win_opts.anchor = popup._pos_map[vim_options.pos]
    end
  else
    win_opts.anchor = "NW" -- This is the default, but makes `posinvert` easier to implement
  end

  -- , fixed    When FALSE (the default), and:
  -- ,      - "pos" is "botleft" or "topleft", and
  -- ,      - "wrap" is off, and
  -- ,      - the popup would be truncated at the right edge of
  -- ,        the screen, then
  -- ,     the popup is moved to the left so as to fit the
  -- ,     contents on the screen.  Set to TRUE to disable this.

  win_opts.style = "minimal"

  -- Feels like maxheight, minheight, maxwidth, minwidth will all be related
  --
  -- maxheight  Maximum height of the contents, excluding border and padding.
  -- minheight  Minimum height of the contents, excluding border and padding.
  -- maxwidth  Maximum width of the contents, excluding border, padding and scrollbar.
  -- minwidth  Minimum width of the contents, excluding border, padding and scrollbar.
  local width = vim_options.width or 1
  local height
  if type(what) == "number" then
    height = vim.api.nvim_buf_line_count(what)
  else
    for _, v in ipairs(what) do
      width = math.max(width, #v)
    end
    height = #what
  end
  win_opts.width = utils.bounded(width, vim_options.minwidth, vim_options.maxwidth)
  win_opts.height = utils.bounded(height, vim_options.minheight, vim_options.maxheight)

  -- posinvert, When FALSE the value of "pos" is always used.  When
  -- ,   TRUE (the default) and the popup does not fit
  -- ,   vertically and there is more space on the other side
  -- ,   then the popup is placed on the other side of the
  -- ,   position indicated by "line".
  if dict_default(vim_options, "posinvert", option_defaults) then
    if win_opts.anchor == "NW" or win_opts.anchor == "NE" then
      if win_opts.row + win_opts.height > vim.o.lines and win_opts.row * 2 > vim.o.lines then
        -- Don't know why, but this is how vim adjusts it
        win_opts.row = win_opts.row - win_opts.height - 2
      end
    elseif win_opts.anchor == "SW" or win_opts.anchor == "SE" then
      if win_opts.row - win_opts.height < 0 and win_opts.row * 2 < vim.o.lines then
        -- Don't know why, but this is how vim adjusts it
        win_opts.row = win_opts.row + win_opts.height + 2
      end
    end
  end

  -- textprop, When present the popup is positioned next to a text
  -- ,   property with this name and will move when the text
  -- ,   property moves.  Use an empty string to remove.  See
  -- ,   |popup-textprop-pos|.
  -- related:
  --   textpropwin
  --   textpropid

  -- zindex, Priority for the popup, default 50.  Minimum value is
  -- ,   1, maximum value is 32000.
  local zindex = dict_default(vim_options, "zindex", option_defaults)
  win_opts.zindex = utils.bounded(zindex, 1, 32000)

  -- noautocmd, undocumented vim default per https://github.com/vim/vim/issues/5737
  win_opts.noautocmd = vim.F.if_nil(vim_options.noautocmd, true)

  -- focusable,
  -- vim popups are not focusable windows
  win_opts.focusable = vim.F.if_nil(vim_options.focusable, false)

  local win_id
  if vim_options.hidden then
    assert(false, "I have not implemented this yet and don't know how")
  else
    win_id = vim.api.nvim_open_win(bufnr, false, win_opts)
  end

  -- Moved, handled after since we need the window ID
  if vim_options.moved then
    if vim_options.moved == "any" then
      vim.lsp.util.close_preview_autocmd({ "CursorMoved", "CursorMovedI" }, win_id)
    elseif vim_options.moved == "word" then
      -- TODO: Handle word, WORD, expr, and the range functions... which seem hard?
    end
  else
    local silent = false
    vim.cmd(
      string.format(
        "autocmd BufDelete %s <buffer=%s> ++once ++nested :lua require('plenary.window').try_close(%s, true)",
        (silent and "<silent>") or "",
        bufnr,
        win_id
      )
    )
  end

  if vim_options.time then
    local timer = vim.loop.new_timer()
    timer:start(
      vim_options.time,
      0,
      vim.schedule_wrap(function()
        Window.try_close(win_id, false)
      end)
    )
  end

  -- Buffer Options
  if vim_options.cursorline then
    vim.api.nvim_win_set_option(win_id, "cursorline", true)
  end

  if vim_options.wrap ~= nil then
    -- set_option wrap should/will trigger autocmd, see https://github.com/neovim/neovim/pull/13247
    if vim_options.noautocmd then
      vim.cmd(string.format("noautocmd lua vim.api.nvim_set_option(%s, wrap, %s)", win_id, vim_options.wrap))
    else
      vim.api.nvim_win_set_option(win_id, "wrap", vim_options.wrap)
    end
  end

  -- ===== Not Implemented Options =====
  -- flip: not implemented at the time of writing
  -- Mouse:
  --    mousemoved: no idea how to do the things with the mouse, so it's an exercise for the reader.
  --    drag: mouses are hard
  --    resize: mouses are hard
  --    close: mouses are hard
  --
  -- scrollbar
  -- scrollbarhighlight
  -- thumbhighlight

  -- tabpage: seems useless

  -- Create border

  local should_show_border = nil
  local border_options = {}

  -- border    List with numbers, defining the border thickness
  --     above/right/below/left of the popup (similar to CSS).
  --     Only values of zero and non-zero are recognized.
  --     An empty list uses a border all around.
  if vim_options.border then
    should_show_border = true

    if type(vim_options.border) == "boolean" or vim.tbl_isempty(vim_options.border) then
      border_options.border_thickness = Border._default_thickness
    elseif #vim_options.border == 4 then
      border_options.border_thickness = {
        top = utils.bounded(vim_options.border[1], 0, 1),
        right = utils.bounded(vim_options.border[2], 0, 1),
        bot = utils.bounded(vim_options.border[3], 0, 1),
        left = utils.bounded(vim_options.border[4], 0, 1),
      }
    else
      error(string.format("Invalid configuration for border: %s", vim.inspect(vim_options.border)))
    end
  elseif vim_options.border == false then
    should_show_border = false
  end

  if (should_show_border == nil or should_show_border) and vim_options.borderchars then
    should_show_border = true

    -- borderchars  List with characters, defining the character to use
    --     for the top/right/bottom/left border.  Optionally
    --     followed by the character to use for the
    --     topleft/topright/botright/botleft corner.
    --     Example: ['-', '|', '-', '|', '┌', '┐', '┘', '└']
    --     When the list has one character it is used for all.
    --     When the list has two characters the first is used for
    --     the border lines, the second for the corners.
    --     By default a double line is used all around when
    --     'encoding' is "utf-8" and 'ambiwidth' is "single",
    --     otherwise ASCII characters are used.

    local b_top, b_right, b_bot, b_left, b_topleft, b_topright, b_botright, b_botleft
    if vim_options.borderchars == nil then
      b_top, b_right, b_bot, b_left, b_topleft, b_topright, b_botright, b_botleft =
        "═", "║", "═", "║", "╔", "╗", "╝", "╚"
    elseif #vim_options.borderchars == 1 then
      local b_char = vim_options.borderchars[1]
      b_top, b_right, b_bot, b_left, b_topleft, b_topright, b_botright, b_botleft =
        b_char, b_char, b_char, b_char, b_char, b_char, b_char, b_char
    elseif #vim_options.borderchars == 2 then
      local b_char = vim_options.borderchars[1]
      local c_char = vim_options.borderchars[2]
      b_top, b_right, b_bot, b_left, b_topleft, b_topright, b_botright, b_botleft =
        b_char, b_char, b_char, b_char, c_char, c_char, c_char, c_char
    elseif #vim_options.borderchars == 8 then
      b_top, b_right, b_bot, b_left, b_topleft, b_topright, b_botright, b_botleft = unpack(vim_options.borderchars)
    else
      error(string.format 'Not enough arguments for "borderchars"')
    end

    border_options.top = b_top
    border_options.bot = b_bot
    border_options.right = b_right
    border_options.left = b_left
    border_options.topleft = b_topleft
    border_options.topright = b_topright
    border_options.botright = b_botright
    border_options.botleft = b_botleft
  end

  -- title
  if vim_options.title then
    -- TODO: Check out how title works with weird border combos.
    border_options.title = vim_options.title
  end

  local border = nil
  if should_show_border then
    border_options.focusable = vim_options.border_focusable
    border = Border:new(bufnr, win_id, win_opts, border_options)
  end

  if vim_options.highlight then
    vim.api.nvim_win_set_option(win_id, "winhl", string.format("Normal:%s", vim_options.highlight))
  end

  if vim_options.borderhighlight then
    vim.api.nvim_win_set_option(border.win_id, "winhl", string.format("Normal:%s", vim_options.borderhighlight))
  end

  -- enter
  local should_enter = vim_options.enter
  if should_enter == nil then
    should_enter = true
  end

  if should_enter then
    -- set focus after border creation so that it's properly placed (especially
    -- in relative cursor layout)
    if vim_options.noautocmd then
      vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. win_id .. ")")
    else
      vim.api.nvim_set_current_win(win_id)
    end
  end

  -- callback
  if vim_options.callback then
    popup._callbacks[bufnr] = function()
      -- (jbyuki): Giving win_id is pointless here because it's closed right afterwards
      -- but it might make more sense once hidden is implemented
      local row, _ = unpack(vim.api.nvim_win_get_cursor(win_id))
      vim_options.callback(win_id, what[row])
      vim.api.nvim_win_close(win_id, true)
    end
    vim.api.nvim_buf_set_keymap(
      bufnr,
      "n",
      "<CR>",
      '<cmd>lua require"popup".execute_callback(' .. bufnr .. ")<CR>",
      { noremap = true }
    )
  end

  -- TODO: Perhaps there's a way to return an object that looks like a window id,
  --    but actually has some extra metadata about it.
  --
  --    This would make `hidden` a lot easier to manage
  return win_id, {
    win_id = win_id,
    border = border,
  }
end

function popup.execute_callback(bufnr)
  if popup._callbacks[bufnr] then
    local wrapper = popup._callbacks[bufnr]
    wrapper()
    popup._callbacks[bufnr] = nil
  end
end

return popup
