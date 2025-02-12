---@class PlenaryFun
local M = {}

M.bind = require("plenary.functional").partial

---@param fn fun(...)
---@param argc integer
---@return fun(...)
function M.arify(fn, argc)
  return function(...)
    if select("#", ...) ~= argc then
      error(("Expected %s number of arguments"):format(argc))
    end

    fn(...)
  end
end

---@param map fun(...)
---@return fun(to_wrap: fun(...)): fun(...)
function M.create_wrapper(map)
  return function(to_wrap)
    return function(...)
      return map(to_wrap(...))
    end
  end
end

return M
