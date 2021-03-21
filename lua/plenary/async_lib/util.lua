local a = require('plenary.async_lib.async')
local await = a.await
local async = a.async
local co = coroutine
local VecDeque = require('plenary.async_lib.helpers').VecDeque
local uv = vim.loop

local M = {}

M.sleep = a.wrap(function(ms, callback)
  local timer = uv.new_timer()
  uv.timer_start(timer, ms, 0, function()
    uv.timer_stop(timer)
    uv.close(timer)
    callback()
  end)
end, 2)

--- Takes a future and a millisecond as the timeout.
--- If the time is reached and the future hasn't completed yet, it will short circuit the future
--- NOTE: the future will still be running in libuv, we are just not waiting for it to complete
--- thats why you should call this on a leaf future only to avoid unexpected results
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

M.timer = function(ms)
  return async(function()
    await(M.sleep(ms))
  end)
end

M.id = async(function(...)
  return ...
end)

M.thread_loop = function(thread, callback)
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

M.thread_loop_async = a.wrap(M.thread_loop, 2)

M.yield_now = async(function()
  await(M.id())
end)

-- will force the future to be runned when called
M.runned = function(future)
  return function(step)
    a.run(future, step)
  end
end

local Condvar = {}
Condvar.__index = Condvar

function Condvar.new()
  return setmetatable({handles = {}}, Condvar)
end

--- async function
--- blocks the thread until a notification is received
Condvar.wait = a.wrap(function(self, callback)
  -- not calling the callback will block the coroutine
  table.insert(self.handles, callback)
end, 2)

--- not an async function
function Condvar:notify_all()
  if #self.handles == 0 then return end

  for _, callback in ipairs(self.handles) do
    callback()
  end
  self.handles = {} -- reset all handles as they have been used up
end

--- not an async function
function Condvar:notify_one()
  if #self.handles == 0 then return end

  local idx = math.random(#self.handles)
  self.handles[idx]()
  table.remove(self.handles, idx)
end

M.Condvar = Condvar

local Semaphore = {}
Semaphore.__index = Semaphore

function Semaphore.new(initial_permits) 
  vim.validate {
    initial_permits = {
      initial_permits,
      function(n) return n > 0 end,
      'number greater than 0'
    }
  }

  return setmetatable({permits = initial_permits, handles = {}}, Semaphore)
end

--- async function, blocks until a permit can be acquired
--- example:
--- local semaphore = Semaphore.new(1024)
--- local permit = await(semaphore:acquire())
--- permit:forget()
--- when a permit can be acquired returns it
--- call permit:forget() to forget the permit
Semaphore.acquire = a.wrap(function(self, callback)
  self.permits = self.permits - 1

  if self.permits <= 0 then
    table.insert(self.handles, callback)
    return
  end

  local permit = {}

  permit.forget = function(self_permit)
    self.permits = self.permits + 1

    if self.permits > 0 and #self.handles > 0 then
      local callback = table.remove(self.handles)
      callback(self_permit)
      self.permits = self.permits - 1
    end
  end

  callback(permit)
end, 2)

M.Semaphore = Semaphore

M.channel = {}

M.channel.oneshot = function()
  local val = nil
  local saved_callback = nil
  local done = false

  --- sender is not async
  --- sends a value
  local sender = function(...)
    local args = {...}

    if #args == 0 then
      error('Cannot send nil value')
    end

    if val ~= nil then
      error('Oneshot channel can only send one value!')
      return
    end

    if saved_callback then
      saved_callback(unpack(val or args))
      done = true
    else
      val = args
    end
  end

  --- receiver is async
  --- blocks until a value is received
  local receiver = a.wrap(function(callback)
    if done then
      error('Oneshot channel can only send one value!')
      return
    end

    if val then
      callback(unpack(val))
      done = true
    else
      saved_callback = callback
    end
  end, 1)

  return sender, receiver
end

M.channel.mpsc = function()
end

local pcall_wrap = function(func)
  return function(...)
    return pcall(func, ...)
  end
end

M.protected_non_leaf = async(function(future)
  return await(pcall_wrap(future))
end)

M.protected = async(function(future)
  local tx, rx = M.channel.oneshot()

  stat, ret = pcall(future, tx)

  if stat == true then
    return stat, await(rx())
  else
    return stat, ret
  end
end)

return M
