local co = coroutine
local uv = vim.loop

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
local pong = function(func, callback)
  assert(type(func) == "function", "type error :: expected func")
  local thread = co.create(func)
  local step
  step = function(...)
    local res = {co.resume(thread, ...)}
    local stat = res[1]
    local ret = {select(2, unpack(res))}
    assert(stat, "Status should be true")
    if co.status(thread) == "dead" then
      (callback or function() end)(unpack(ret))
    else
      assert(#ret == 1, "expected a single return value")
      assert(type(ret[1]) == "function", "type error :: expected func")
      ret[1](step)
    end
  end
  step()
end

-- use with pong, creates thunk factory
local wrap = function(func)
  assert(type(func) == "function", "type error :: expected func, got " .. type(func))

  return function(...)
    local params = {...}
    return function(step)
      table.insert(params, step)
      return func(unpack(params))
    end
  end
end

local thread_loop_async = wrap(thread_loop)

-- many thunks -> single thunk
local join = function(thunks)
  local len = #thunks
  local done = 0
  local acc = {}

  local thunk = function(step)
    if len == 0 then
      return step()
    end
    for i, tk in ipairs(thunks) do
      assert(type(tk) == "function", "thunk must be function")
      local callback = function(...)
        acc[i] = {...}
        done = done + 1
        if done == len then
          step(unpack(acc))
        end
      end
      tk(callback)
    end
  end
  return thunk
end

local function run(future)
  future()
end

local function run_all(futures)
  for _, future in ipairs(futures) do
    future()
  end
end

-- sugar over coroutine
local await = function(defer)
  assert(type(defer) == "function", "type error :: expected func")
  return co.yield(defer)
end


local await_all = function(defer)
  assert(type(defer) == "table", "type error :: expected table")
  return co.yield(join(defer))
end

local async = function(func)
  return function(...)
    local args = {...}
    return wrap(pong)(function()
      return func(unpack(args))
    end)
  end
end

local pong_loop = async(function(func, callback)
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

--- because idle is a bad name
local spawn = wrap(pong_loop)

return {
  async = async,
  join = join,
  await = await,
  await_all = await_all,
  run = run,
  run_all = run_all,
  spawn = spawn,
  wrap = wrap,
  wait_for_textlock = wrap(vim.schedule)
} 
