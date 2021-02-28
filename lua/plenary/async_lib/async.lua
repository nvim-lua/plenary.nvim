local co = coroutine
local uv = vim.loop

local M = {}


--- WIP idle stuff
local thread_loop = function(thread, callback)
  local idle = uv.new_idle()
  idle:start(function()
    local success = co.resume(thread)
    assert(success, "Coroutine failed")

    if co.status(thread) == "dead" then
      idle:stop()
      callback()
    end
  end)
end

-- use with wrap
local execute = function(func, callback)
  assert(type(func) == "function", "type error :: expected func")
  local thread = co.create(func)

  local next
  next = function(...)
    local res = {co.resume(thread, ...)}
    local stat = res[1]
    local ret = {select(2, unpack(res))}

    assert(stat, string.format("The coroutine failed with this message: %s", ret[1]))

    if co.status(thread) == "dead" then
      (callback or function() end)(unpack(ret))
    else
      assert(#ret == 1, "expected a single return value")
      assert(type(ret[1]) == "function", "type error :: expected func")
      ret[1](next)
    end
  end

  next()
end

-- use with CPS function, creates thunk factory
M.wrap = function(func)
  assert(type(func) == "function", "type error :: expected func, got " .. type(func))

  return function(...)
    local params = {...}
    local function thunk(step)
      if step then
        table.insert(params, step)
        return func(unpack(params))
      else
        return co.yield(thunk)
      end
    end
    return thunk
  end
end
--- WIP
local thread_loop_async = M.wrap(thread_loop)

-- many futures -> single future
M.join = M.wrap(function(futures, step)
  local len = #futures
  local results = {}
  local done = 0

  if len == 0 then
    return step(results)
  end
  for i, future in ipairs(futures) do
    assert(type(future) == "function", "thunk must be function")
    local callback = function(...)
      results[i] = {...} -- should we set this to a table
      done = done + 1
      if done == len then
        -- step(unpack(results))
        step(results) -- should we unpack?
      end
    end
    future(callback)
  end

end)

--- use this over running a future by calling it with no callback argument because it is more explicit
M.run = function(future, callback)
  future(callback or function() end)
end

M.run_all = function(futures, callback) M.run(M.join(futures), callback) end

-- sugar over coroutine
M.await = function(future)
  return future(nil)
end


M.await_all = function(futures)
  assert(type(futures) == "table", "type error :: expected table")
  return M.await(M.join(futures))
end

-- suspend co-routine, call function with its continuation (like call/cc)
M.suspend = co.yield

M.async = function(func)
  return function(...)
    local args = {...}
    local function run (step)
      if step ==  nil then
        return func(unpack(args))
      else
        execute(run, step)
      end
    end
    return run
  end
end

--- WIP
local execute_loop = M.async(function(func, callback)
  assert(type(func) == "function", "type error :: expected func")
  local thread = co.create(func)

  local _step
  _step = function(...)
    local res = {co.resume(thread, ...)}
    local stat = res[1]
    local ret = {select(2, unpack(res))}
    assert(stat, "Status should be true")
    if co.status(thread) == "dead" then
      (callback or function() end)(unpack(ret))
    else
      assert(#ret == 1, "expected a single return value")
      assert(type(ret[1]) == "function", "type error :: expected func")
      -- yield before calling the next one
      co.yield()
      ret[1](_step)
    end
  end

  local step = function()
    thread_loop(co.create(_step))
  end

  step()
end)

--- WIP
--- because idle is a bad name
M.spawn = M.wrap(execute_loop)

return M
