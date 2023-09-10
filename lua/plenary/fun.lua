local M = {}

M.bind = require("plenary.functional").partial

function M.arify(fn, argc)
  return function(...)
    if select("#", ...) ~= argc then
      error(("Expected %s number of arguments"):format(argc))
    end

    fn(...)
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
