local i = require'plenary.iterators'

local parsec = {}

local Recoverable = {}
Recoverable.__index = Recoverable

function Recoverable:tostring()
  return self.message
end

function recoverable(message, level)
  level = level or 1
  error(setmetatable({message = message}, Recoverable), level + 1)
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

function parsec.satisfy(f)
  local got_to = 1

  return function(s)
    i.iter(s)
      :filter(f)
      :for_each(function(char)
        got_to = got_to + #char
      end)

    if got_to == 1 then
      recoverable("The first char did not satisfy the predicate")
    else
      return s:sub(1, got_to - 1), s:sub(got_to)
    end
  end
end

return parsec
