local path = require("plenary.path").path

local M = {}

M.strdisplaywidth = (function()
  if jit and path.sep ~= [[\]] then
    local ffi = require "ffi"
    ffi.cdef [[
      typedef unsigned char char_u;
      int linetabsize_col(int startcol, char_u *s);
    ]]

    return function(str, col)
      str = tostring(str)
      local startcol = col or 0
      local s = ffi.new("char[?]", #str + 1)
      ffi.copy(s, str)
      return ffi.C.linetabsize_col(startcol, s) - startcol
    end
  else
    return function(str, col)
      str = tostring(str)
      if vim.in_fast_event() then
        return #str - (col or 0)
      end
      return vim.fn.strdisplaywidth(str, col)
    end
  end
end)()

M.strcharpart = (function()
  if jit and path.sep ~= [[\]] then
    local ffi = require "ffi"
    ffi.cdef [[
      typedef unsigned char char_u;
      int utf_ptr2len(const char_u *const p);
    ]]

    local function utf_ptr2len(str)
      local c_str = ffi.new("char[?]", #str + 1)
      ffi.copy(c_str, str)
      return ffi.C.utf_ptr2len(c_str)
    end

    return function(str, nchar, charlen)
      local nbyte = 0
      if nchar > 0 then
        while nchar > 0 and nbyte < #str do
          nbyte = nbyte + utf_ptr2len(str:sub(nbyte + 1))
          nchar = nchar - 1
        end
      else
        nbyte = nchar
      end

      local len = 0
      if charlen then
        while charlen > 0 and nbyte + len < #str do
          local off = nbyte + len
          if off < 0 then
            len = len + 1
          else
            len = len + utf_ptr2len(str:sub(off + 1))
          end
          charlen = charlen - 1
        end
      else
        len = #str - nbyte
      end

      if nbyte < 0 then
        len = len + nbyte
        nbyte = 0
      elseif nbyte > #str then
        nbyte = #str
      end
      if len < 0 then
        len = 0
      elseif nbyte + len > #str then
        len = #str - nbyte
      end

      return str:sub(nbyte + 1, nbyte + len)
    end
  else
    return function(str, nchar, charlen)
      if vim.in_fast_event() then
        return str:sub(nchar + 1, charlen)
      end
      return vim.fn.strcharpart(str, nchar, charlen)
    end
  end
end)()

M.truncate = function(str, len, dots)
  str = tostring(str) -- We need to make sure its an actually a string and not a number
  dots = dots or "…"
  if M.strdisplaywidth(str) <= len then
    return str
  end
  local start = 0
  local current = 0
  local result = ""
  local len_of_dots = M.strdisplaywidth(dots)
  while true do
    local part = M.strcharpart(str, start, 1)
    current = current + M.strdisplaywidth(part)
    if (current + len_of_dots) > len then
      result = result .. dots
      break
    end
    result = result .. part
    start = start + 1
  end
  return result
end

M.align_str = function(string, width, right_justify)
  local str_len = M.strdisplaywidth(string)
  return right_justify and string.rep(" ", width - str_len) .. string or string .. string.rep(" ", width - str_len)
end

M.dedent = function(str, leave_indent)
  -- Check each line and detect the minimum indent.
  local indent
  local info = {}
  for line in str:gmatch "[^\n]*\n?" do
    -- It matches '' for the last line.
    if line ~= "" then
      local chars, width
      local line_indent = line:match "^[ \t]+"
      if line_indent then
        chars = #line_indent
        width = M.strdisplaywidth(line_indent)
        if not indent or width < indent then
          indent = width
        end
        -- Ignore empty lines
      elseif line ~= "\n" then
        indent = 0
      end
      table.insert(info, { line = line, chars = chars, width = width })
    end
  end

  -- Build up the result
  leave_indent = leave_indent or 0
  local result = {}
  for _, i in ipairs(info) do
    local line
    if i.chars then
      local content = i.line:sub(i.chars + 1)
      local indent_width = i.width - indent + leave_indent
      line = (" "):rep(indent_width) .. content
    elseif i.line == "\n" then
      line = "\n"
    else
      line = (" "):rep(leave_indent) .. i.line
    end
    table.insert(result, line)
  end
  return table.concat(result)
end

return M
