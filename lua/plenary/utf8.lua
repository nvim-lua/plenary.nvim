---@brief [[
---Borrowed from https://github.com/britzl/gooey/blob/master/gooey/internal/utf8.lua
---Simple utf8 library.
---No support for regex.
---@brief ]]

local i = require('plenary.iterators')
local byte    = string.byte
local char    = string.char
local dump    = string.dump
local find    = string.find
local format  = string.format
local len     = string.len
local lower   = string.lower
local rep     = string.rep
local sub     = string.sub
local upper   = string.upper

local utf8 = {}

---Returns the number of bytes used by the UTF-8 character at byte i in s.
---Also doubles as a UTF-8 character validator.
---This way we don't have to do this terrible thing anymore: [%z\1-\127\194-\244][\128-\191]*.
---@param s string
---@param i number
---@return number
function utf8.charbytes(s, i)
  -- argument defaults
  i = i or 1

  -- argument checking
  if type(s) ~= "string" then
    error("bad argument #1 to 'utf8charbytes' (string expected, got ".. type(s).. ")")
  end
  if type(i) ~= "number" then
    error("bad argument #2 to 'utf8charbytes' (number expected, got ".. type(i).. ")")
  end

  local c = byte(s, i)

  -- determine bytes needed for character, based on RFC 3629
  -- validate byte 1
  if c > 0 and c <= 127 then
    -- UTF8-1
    return 1

  elseif c >= 194 and c <= 223 then
    -- UTF8-2
    local c2 = byte(s, i + 1)

    if not c2 then
      error("UTF-8 string terminated early")
    end

    -- validate byte 2
    if c2 < 128 or c2 > 191 then
      error("Invalid UTF-8 character")
    end

    return 2

  elseif c >= 224 and c <= 239 then
    -- UTF8-3
    local c2 = byte(s, i + 1)
    local c3 = byte(s, i + 2)

    if not c2 or not c3 then
      error("UTF-8 string terminated early")
    end

    -- validate byte 2
    if c == 224 and (c2 < 160 or c2 > 191) then
      error("Invalid UTF-8 character")
    elseif c == 237 and (c2 < 128 or c2 > 159) then
      error("Invalid UTF-8 character")
    elseif c2 < 128 or c2 > 191 then
      error("Invalid UTF-8 character")
    end

    -- validate byte 3
    if c3 < 128 or c3 > 191 then
      error("Invalid UTF-8 character")
    end

    return 3

  elseif c >= 240 and c <= 244 then
    -- UTF8-4
    local c2 = byte(s, i + 1)
    local c3 = byte(s, i + 2)
    local c4 = byte(s, i + 3)

    if not c2 or not c3 or not c4 then
      error("UTF-8 string terminated early")
    end

    -- validate byte 2
    if c == 240 and (c2 < 144 or c2 > 191) then
      error("Invalid UTF-8 character")
    elseif c == 244 and (c2 < 128 or c2 > 143) then
      error("Invalid UTF-8 character")
    elseif c2 < 128 or c2 > 191 then
      error("Invalid UTF-8 character")
    end

    -- validate byte 3
    if c3 < 128 or c3 > 191 then
      error("Invalid UTF-8 character")
    end

    -- validate byte 4
    if c4 < 128 or c4 > 191 then
      error("Invalid UTF-8 character")
    end

    return 4

  else
    error("Invalid UTF-8 character")
  end
end

-- returns the number of characters in a UTF-8 string
function utf8.len(s)
  -- argument checking
  if type(s) ~= "string" then
    for k,v in pairs(s) do print('"',tostring(k),'"',tostring(v),'"') end
    error("bad argument #1 to 'utf8len' (string expected, got ".. type(s).. ")")
  end

  local pos = 1
  local bytes = len(s)
  local length = 0

  while pos <= bytes do
    length = length + 1
    pos = pos + utf8.charbytes(s, pos)
  end

  return length
end

-- functions identically to string.sub except that i and j are UTF-8 characters
-- instead of bytes
function utf8.sub(s, i, j)
  -- argument defaults
  j = j or -1

  local pos = 1
  local bytes = len(s)
  local length = 0

  -- only set l if i or j is negative
  local l = (i >= 0 and j >= 0) or utf8.len(s)
  local startChar = (i >= 0) and i or l + i + 1
  local endChar   = (j >= 0) and j or l + j + 1

  -- can't have start before end!
  if startChar > endChar then
    return ""
  end

  -- byte offsets to pass to string.sub
  local startByte,endByte = 1,bytes

  while pos <= bytes do
    length = length + 1

    if length == startChar then
      startByte = pos
    end

    pos = pos + utf8.charbytes(s, pos)

    if length == endChar then
      endByte = pos - 1
      break
    end
  end

  if startChar > length then startByte = bytes+1   end
  if endChar   < 1      then endByte   = 0         end

  return sub(s, startByte, endByte)
end

function utf8.chars_gen(param, state)
    local str, length = param[1], param[2]
    local byte_pos = state
    local start = byte_pos

    if byte_pos > length then return nil end
    local bytes = utf8.charbytes(str, byte_pos)
    byte_pos    = byte_pos + bytes

    local last  = byte_pos-1
    local slice = sub(str,start,last)
    return byte_pos, slice, start, last
end

function utf8.chars(str)
  return i.wrap(utf8.chars_gen, {str, #str}, 1)
end

return utf8
