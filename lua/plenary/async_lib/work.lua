local a = require('plenary.async_lib.async')
local uv = vim.loop

local M = {}

local function work_map(tbl, func, callback)
  local results = {}
  local ran_callback = false

  local work = uv.new_work(func, function(idx, ...)
    results[idx] = {...}
    if #results == #tbl and ran_callback == false then
      callback(results)
      ran_callback = true
    end
  end)

  for idx, v in ipairs(tbl) do
    M.validate_threadargs(v)

    work:queue(idx, v)
  end
end

M.map_async = a.wrap(work_map, 3)

function M.is_threadarg(t)
  return type(t) == "nil" or type(t) == "boolean" or type(t) == "number" or type(t) == "string" or type(t) == "userdata"
end

function M.validate_threadargs(...)
  for arg in ipairs({...}) do
    if not M.is_threadarg(arg) then
      error('Was not a threadarg')
    end
  end
end

--- wrap function to execute in threadpool.
--- need to figure out what work does
--- this functions wraps it for a callback api
--- WARNING: func cannot have any upvalues, only lua standard library
--- WARNING: func can only be passed threadargs, see above
function M.work_wrap(func)
  return function(...)
    local args = {...}
    local callback = table.remove(args)

    M.validate_threadargs(unpack(args))

    local work = uv.new_work(func, callback)
    uv.queue_work(work, unpack(args))
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

M.string.match = M.async_work_wrap(function(...)
  return string.match(...)
end)

M.string.find = M.async_work_wrap(function(...)
  return string.find(...)
end)

M.thread = a.wrap(function(opts, callback)
  local func = opts.func
  local args = opts.args

  local async
  async = uv.new_async(function(...)
    callback(...)
    async:close()
  end)

  M.validate_threadargs(unpack(args))

  table.insert(args, 1, async)

  uv.new_thread(func, unpack(args))
end)

return M
