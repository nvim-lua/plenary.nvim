local tbl = require('plenary.tbl')

local M = {}

function M.bind(fn, ...)
  if select('#', ...) == 1 then
    local arg = ...
    return function(...)
      fn(arg, ...)
    end
  end

  local args = tbl.pack(...)
  return function(...)
    fn(tbl.unpack(args), ...)
  end
end

function M.create_wrapper(map)
  return function(to_wrap)
    return function(...)
      return map(to_wrap(...))
    end
  end
end

return M
