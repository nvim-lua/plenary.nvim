--- popup.lua
---
--- Wrapper to make the popup api from vim in neovim.
--- Hope to get this part merged in at some point in the future.

local vim = vim

local popup = {}

popup._pos_map = {
  topleft="NW",
  topright="NE",
  botleft="SW",
  botright="SE",
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


function popup.popup_create(what, options)
  local buf
  if type(what) == 'number' then
    buf = what
  else
    buf = vim.fn.nvim_create_buf(false, true)

    -- TODO: Handle list of lines
    vim.fn.nvim_buf_set_lines(buf, 0, -1, true, {what})
  end

  local option_defaults = {
    posinvert = true
  }

  local win_opts = {}

  if options.line then
    -- TODO: Need to handle "cursor", "cursor+1", ...
    win_opts.row = options.line
  else
    -- TODO: It says it needs to be "vertically cenetered"?...
    -- wut is that.
    win_opts.row = 0
  end

  if options.col then
    -- TODO: Need to handle "cursor", "cursor+1", ...
    win_opts.col = options.col
  else
    -- TODO: It says it needs to be "horizontally cenetered"?...
    win_opts.col = 0
  end

  if options.pos then
    if options.pos == 'center' then
      -- TODO: Do centering..
    else
      win_opts.anchor = popup._pos_map[options.pos]
    end
  end

  -- posinvert	When FALSE the value of "pos" is always used.  When
  -- 		TRUE (the default) and the popup does not fit
  -- 		vertically and there is more space on the other side
  -- 		then the popup is placed on the other side of the
  -- 		position indicated by "line".
  if dict_default(options, 'posinvert', option_defaults) then
    -- TODO: handle the invert thing
  end

  -- 	fixed		When FALSE (the default), and:
  -- 			 - "pos" is "botleft" or "topleft", and
  -- 			 - "wrap" is off, and
  -- 			 - the popup would be truncated at the right edge of
  -- 			   the screen, then
  -- 			the popup is moved to the left so as to fit the
  -- 			contents on the screen.  Set to TRUE to disable this.

  win_opts.style = 'minimal'

  -- Feels like maxheigh, minheight, maxwidth, minwidth will all be related

  -- textprop	When present the popup is positioned next to a text
  -- 		property with this name and will move when the text
  -- 		property moves.  Use an empty string to remove.  See
  -- 		|popup-textprop-pos|.
  -- related:
  --   textpropwin
  --   textpropid

  -- border
  local top, left, right, bottom
  if options.border then
    local b_top, b_rgight, b_bot, b_left, b_topleft, b_topright, b_botright, b_botleft
    if options.borderchars == nil then
      b_top , b_rgight , b_bot , b_left , b_topleft , b_topright , b_botright , b_botleft = {
        '-' , '|'      , '-'   , '|'    , '┌'        , '┐'       , '┘'       , '└'
      }
    elseif #options.borderchars == 1 then
      -- TODO: Unpack 8 times cool to the same vars
      print('...')
    elseif #options.borderchars == 2 then
      -- TODO: Unpack to edges & corners
      print('...')
    elseif #options.borderchars == 8 then
      b_top , b_rgight , b_bot , b_left , b_topleft , b_topright , b_botright , b_botleft = options.borderhighlight
    end

    print(b_top, b_rgight, b_bot, b_left, b_topleft, b_topright, b_botright, b_botleft)
    print(top, left, right, bottom)
  end

  -- title
  if options.title then
    if options.border then
      -- TODO: Replace middle section of border with title
      local start, finish = 1, 2
      top = string.sub(1, start) .. options.title .. string.sub(finish, -1)
    else
      -- TODO: This should really be centered
      top = " " .. options.title .. " "
    end
  end

  local win_id
  if options.hidden then
    assert(false, "I have not implemented this yet and don't know how")
  else
    win_id = vim.fn.nvim_open_win(buf, 0, win_opts)
  end


  -- Moved, handled after since we need the window ID
  if options.moved then
    if options.moved == 'any' then
      vim.lsp.util.close_preview_autocmd({'CursorMoved', 'CursorMovedI'}, win_id)
    elseif options.moved == 'word' then
      -- TODO: Handle word, WORD, expr, and the range functions... which seem hard?
    end
  end

  if options.time then
    local timer = vim.loop.new_timer()
    timer:start(options.time, 0, vim.schedule_wrap(function()
      vim.fn.nvim_close_win(win_id, false)
    end))
  end

  -- Buffer Options
  if options.cursorline then
    vim.fn.nvim_win_set_option(0, 'cursorline', true)
  end

  vim.fn.nvim_win_set_option(0, 'wrap', dict_default(options, 'wrap', option_defaults))

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
  --
  -- tabpage: seems useless


  -- TODO: Perhaps there's a way to return an object that looks like a window id,
  --    but actually has some extra metadata about it.
  --
  --    This would make `hidden` a lot easier to manage
  return win_id
end

function popup.show(self, asdf)
end

popup.show = function()
end

return popup

