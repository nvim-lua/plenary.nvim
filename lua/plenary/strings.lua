local path = require('plenary.path').path

local M = {}

M.strdisplaywidth = (function()
  if jit and path.sep ~= [[\]] then
    local ffi = require('ffi')
    ffi.cdef[[
      typedef unsigned char char_u;
      int linetabsize_col(int startcol, char_u *s);
    ]]

    return function(str, col)
      local startcol = col or 0
      local s = ffi.new('char[?]', #str + 1)
      ffi.copy(s, str)
      return ffi.C.linetabsize_col(startcol, s) - startcol
    end
  else
    return function(str, col)
      return #str - (col or 0)
    end
  end
end)()

M.utf_ptr2len = (function()
  if jit and path.sep ~= [[\]] then
    local ffi = require('ffi')
    ffi.cdef[[
      typedef unsigned char char_u;
      int utf_ptr2len(const char_u *const p);
    ]]

    return function(str)
      local c_str = ffi.new('char[?]', #str + 1)
      ffi.copy(c_str, str)
      return ffi.C.utf_ptr2len(c_str)
    end
  else
    return function(str)
      return str == '' and 0 or 1
    end
  end
end)()

M.strcharpart = function(str, nchar, charlen)
  local nbyte = 0
  if nchar > 0 then
    while nchar > 0 and nbyte < #str do
      nbyte = nbyte + M.utf_ptr2len(str:sub(nbyte + 1))
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
        len = len + M.utf_ptr2len(str:sub(off + 1))
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

M.truncate = function(str, len, dots)
  str = tostring(str) -- We need to make sure its an actually a string and not a number
  dots = dots or '…'
  if M.strdisplaywidth(str) <= len then
    return str
  end
  local start = 0
  local current = 0
  local result = ''
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
  return right_justify
    and string.rep(" ", width - str_len)..string
    or string..string.rep(" ", width - str_len)
end

return M
