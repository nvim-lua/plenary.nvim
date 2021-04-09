local utf8 = require('plenary.utf8')

local M = {}

local Recoverable = {}
Recoverable.__index = Recoverable

function Recoverable:tostring()
  return self.message
end

function recoverable(message, level)
  return setmetatable({message = message}, Recoverable)
end

function is_recoverable(e)
  return getmetatable(e) == Recoverable
end

local Fatal = {}
Fatal.__index = Fatal

function Fatal:tostring()
  return self.message
end

function fatal(message)
  return setmetatable({message = message}, Recoverable)
end

function is_fatal(e)
  return getmetatable(e) == Fatal
end

local class = function()
  local obj = {}

  obj.__index = obj
  obj.__call = function(t, fun)
    return setmetatable({fun = fun}, t)
  end
  -- function obj:__call(fun)
  --   return setmetatable({fun = fun}, self)
  -- end

  return obj
end

local Parser = callable_obj()

function Parser:__tostring()
  return '<parser>'
end

function Parser:__call(s)
  local stat, i, o = self:parse(s)
  if stat == true then
    return i, o
  elseif is_fatal(stat) or is_recoverable(stat) then
    error(tostring(stat))
  end
end

function Parser:parse(s)
  return self.fun(s)
end

M.Parser = Parser

function M.is_letter(c)
  local code = string.byte(c, 1)
  return (#c == 1) and (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
end

function M.is_number(c)
  local code = string.byte(c, 1)
  return (#c == 1) and (code >= 48 and code <= 57)
end

function M.is_alphanumeric(c)
  return M.is_letter(c) or M.is_number(c)
end

function M.satisfy(f)
  local got_to = 1

  return Parser(function(s)
    utf8.chars(s)
      :filter(f)
      :for_each(function(char)
        got_to = got_to + #char
      end)

    if got_to == 1 then
      return recoverable("Satisfy could not consume anything"), s, ""
    else
      return true, s:sub(got_to), s:sub(1, got_to - 1)
    end
  end)
end

M.letter = M.satisfy(M.is_letter)

M.number = M.satisfy(M.is_number)

M.alphanumeric = M.satisfy(M.alphanumeric)

return M
