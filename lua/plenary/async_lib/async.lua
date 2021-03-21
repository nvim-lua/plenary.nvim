local co = coroutine
local uv = vim.loop

local M = {}

-- use with wrap
local execute = function(future, callback)
  assert(type(future) == "function", "type error :: expected func")
  local thread = co.create(future)

  local step
  step = function(...)
    local res = {co.resume(thread, ...)}
    local stat = res[1]
    local ret = {select(2, unpack(res))}

    assert(stat, string.format("The coroutine failed with this message: %s", ret[1]))

    if co.status(thread) == "dead" then
      (callback or function() end)(unpack(ret))
    else
      assert(#ret == 1, "expected a single return value")
      local returned_future = ret[1]
      assert(type(returned_future) == "function", "type error :: expected func")
      returned_future(step)
    end
  end

  step()
end

-- use with CPS function, creates future factory
-- must have argc for arity checking
M.wrap = function(func, argc)
  assert(type(func) == "function", "type error :: expected func, got " .. type(func))
  assert(type(argc) == "number" or argc == "vararg", "expected argc to be a number or string literal 'vararg'")

  return function(...)
    local params = {...}

    local function future(step)
      if step then
        if type(argc) == "number" then
          params[argc] = step
        else
          table.insert(params, step) -- change once not optional
        end
        return func(unpack(params))
      else
        return co.yield(future)
      end
    end
    return future
  end
end

-- many futures -> single future
M.join = M.wrap(function(futures, step)
  local len = #futures
  local results = {}
  local done = 0

  if len == 0 then
    return step(results)
  end

  for i, future in ipairs(futures) do
    assert(type(future) == "function", "type error :: future must be function")

    local callback = function(...)
      results[i] = {...}
      done = done + 1
      if done == len then
        step(results)
      end
    end

    future(callback)
  end
end, 2)

M.select = M.wrap(function(futures, step)
  local selected = false

  for _, future in ipairs(futures) do
    assert(type(future) == "function", "type error :: future must be function")

    local callback = function(...)
      if not selected then
        selected = true
        step(...)
      end
    end

    future(callback)
  end
end, 2)

--- use this over running a future by calling it with no callback argument because it is more explicit
M.run = function(future, callback)
  future(callback or function() end)
end

M.run_all = function(futures, callback)
  M.run(M.join(futures), callback)
end

M.await = function(future)
  return future(nil)
end

M.await_all = function(futures)
  assert(type(futures) == "table", "type error :: expected table")
  return M.await(M.join(futures))
end

-- suspend co-routine, call function with its continuation (like call/cc)
M.suspend = co.yield

M.scope = function(func)
  M.run(M.future(func))
end

--- Future a :: a -> (a -> ())
--- turns this signature
--- ... -> Future a
--- into this signature
--- ... -> ()
M.void = function(async_func)
  return function(...)
    async_func(...)(function() end)
  end
end

M.async = function(func)
  return function(...)
    local args = {...}
    local function future(step)
      if step == nil then
        return func(unpack(args))
      else
        execute(future, step)
      end
    end
    return future
  end
end

M.future = function(func)
  return M.async(func)()
end

M.scheduler = M.wrap(vim.schedule, 1)

---This will COMPLETELY block neovim
---please just use a.run unless you have a very special usecase
---for example, used in plenary test_harness you must use this
M.block_on = function(future, timeout)
  local res

  local stat, ret = pcall(function()
    M.run(future, function(...)
      res = {...}
    end)
  end)

  local function check()
    if stat == false then
      error("Blocking on future failed " .. ret)
    end
    return res ~= nil
  end

  if not vim.wait(timeout or 2000, check, 50, false) then
    error("Blocking on future timed out or was interrupted")
  end

  return unpack(res)
end

return M
