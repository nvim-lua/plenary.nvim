local a = require('plenary.async_lib.async')
local await = a.await
local async = a.async
local vararg = require('plenary.vararg')
local uv = vim.loop
-- local control = a.control
local control = require('plenary.async_lib.control')
local channel = control.channel

local M = {}

---Sleep for milliseconds
---@param ms number
M.sleep = a.wrap(function(ms, callback)
  local timer = uv.new_timer()
  uv.timer_start(timer, ms, 0, function()
    uv.timer_stop(timer)
    uv.close(timer)
    callback()
  end)
end, 2)

---Takes a future and a millisecond as the timeout.
---If the time is reached and the future hasn't completed yet, it will short circuit the future
---NOTE: the future will still be running in libuv, we are just not waiting for it to complete
---thats why you should call this on a leaf future only to avoid unexpected results
---@param future Future
---@param ms number
M.timeout = a.wrap(function(future, ms, callback)
  -- make sure that the callback isn't called twice, or else the coroutine can be dead
  local done = false

  local timeout_callback = function(...)
    if not done then
      done = true
      callback(false, ...) -- false because it has run normally
    end
  end

  vim.defer_fn(function()
    if not done then
      done = true
      callback(true) -- true because it has timed out
    end
  end, ms)

  a.run(future, timeout_callback)
end, 3)

---create an async function timer
---@param ms number
M.timer = function(ms)
  return async(function()
    await(M.sleep(ms))
  end)
end

---This will COMPLETELY block neovim
---please just use a.run unless you have a very special usecase
---for example, in plenary test_harness you must use this
---@param async_function Future
---@param timeout number: Stop blocking if the timeout was surpassed. Default 2000.
M.block_on = function(async_function, timeout)
  async_function = M.protected(async_function)

  local stat, ret

  a.run(async_function, function(_stat, ...)
    stat = _stat
    ret = {...}
  end)

  local function check()
    if stat == false then
      error("Blocking on future failed " .. unpack(ret))
    end
    return stat == true
  end

  if not vim.wait(timeout or 2000, check, 20, false) then
    error("Blocking on future timed out or was interrupted")
  end

  return unpack(ret)
end

M.will_block = function(async_func)
  return function()
    M.block_on(async_func)
  end
end

M.join = function(async_fns)
  local len = #async_fns
  local results = {}
  local done = 0

  local tx, rx = channel.oneshot()

  for i, async_fn in ipairs(async_fns) do
    assert(type(async_fn) == "function", "type error :: future must be function")

    local cb = function(...)
      results[i] = {...}
      done = done + 1
      if done == len then
        tx()
      end
    end

    a.run(async_fn, cb)
  end

  rx()

  return results
end

M.run_all = function(async_fns, callback)
  a.run(function()
    M.join(async_fns)
  end, callback)
end

function M.apcall(async_fn, ...)
  if a.is_leaf_function(async_fn) then
    local tx, rx = channel.oneshot()
    local stat, ret = pcall(async_fn, vararg.rotate(tx, ...))
    if not stat then
      return stat, ret
    else
      return stat, rx()
    end
  else
    return pcall(async_fn, ...)
  end
end

function M.protected(async_fn)
  return function()
    return M.apcall(async_fn)
  end
end

return M
