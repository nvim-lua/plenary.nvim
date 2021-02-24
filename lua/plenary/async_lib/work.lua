local a = require('plenary.async_lib.async')
local uv = vim.loop

local M = {}

local function is_threadarg(t)
  return type(t) == "nil" or type(t) == "boolean" or type(t) == "number" or type(t) == "string" or type(t) == "userdata"
end

function M.validate_threadargs(...)
  for arg in ipairs({...}) do
    if not is_threadarg(arg) then
      error(string.format('%s was not a threadarg', arg))
    end
  end
end

--- wrap a cpu bound function to execute in threadpool.
--- this functions wraps it for a callback api
--- WARNING: func cannot have any upvalues, only lua standard library
--- WARNING: func can only be passed threadargs, see above
function M.work_wrap(func)
  return function(...)
    local args = {...}
    local callback = table.remove(args)

    M.validate_threadargs(unpack(args))

    local work = uv.new_work(func, callback)
    work:queue(unpack(args))
  end
end

--- wrap a cpu bound function (like string processing) to execute in threadpool.
--- This one wraps it for the async context
--- WARNING: func cannot have any upvalues, only lua standard library
--- WARNING: func can only be passed threadargs, see above
function M.async_work_wrap(func)
  return a.wrap(M.work_wrap(func))
end

M.string = {}

M.string.match = M.async_work_wrap(string.match)
M.string.find = M.async_work_wrap(string.find)

return M
