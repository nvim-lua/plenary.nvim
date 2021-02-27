local co = coroutine
local uv = vim.loop

local M = {}

local Future = {}

function Future.new(opts)
  vim.validate {
    leaf = {opts.leaf, 'boolean'},
    args = {opts.args, 'table'},
    func = {opts.func, 'function'},
  }

  local self = {}
  self.leaf = opts.leaf
  if opts.leaf then
    table.insert(opts.args, function() end)
  end
  self.args = opts.args
  self.func = opts.func
  return self
end

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
local execute = function(future, callback)
  callback = callback or function() end

  local thread = co.create(function()
    return future.func(unpack(future.args))
  end)

  local next
  next = function(...)
    local res = {co.resume(thread, ...)}
    local stat = res[1]
    local ret = {select(2, unpack(res))}

    assert(stat, string.format("The coroutine failed with this message: %s", ret[1]))

    if co.status(thread) == "dead" then
      -- (callback or function() end)(unpack(ret))
      callback(unpack(ret))
    else
      local leaf = ret[1]
      leaf.args[#leaf.args] = next
      leaf.func(unpack(leaf.args))
    end
  end

  next()
end

-- use with execute, creates thunk factory
M.wrap = function(func)
  vim.validate {
    func = {func, 'function'}
  }

  return function(...)
    return Future.new {
      leaf = true,
      args = {...},
      func = func,
    }
  end
end

--- WIP
local thread_loop_async = M.wrap(thread_loop)

-- many futures -> single future
M.join = function(futures)

  local combined_future = Future.new {
    leaf = true,
    args = {},
    func = function(callback)
      local len = #futures
      local results = {}
      local done = 0

      if len == 0 then
        return callback()
      end

      for i, future in ipairs(futures) do

        local individual_callback = function(...)
          results[i] = {...} -- should we set this to a table
          done = done + 1
          if done == len then
            callback(results) -- should we unpack?
          end
        end

        if future.leaf then
          future.args[#future.args] = individual_callback
          future.func(unpack(future.args))
        else
          M.run(future, individual_callback)
        end
      end
    end
  }

  return combined_future
end

--- use this over running a future by calling it with no callback argument because it is more explicit
M.run = function(future, callback)
  -- if future.leaf then
    -- future = M.async(function()
    --   return M.await(future)
    -- end)()
  -- end

  execute(future, callback)
end

M.run_all = function(futures, callback) M.run(M.join(futures), callback) end

-- sugar over coroutine
M.await = function(future)
  if future.leaf then
    return co.yield(future)
  else
    return future.func(unpack(future.args))
  end
end


M.await_all = function(futures)
  assert(type(futures) == "table", "type error :: expected table")
  return M.await(M.join(futures))
end

M.async = function(func)
  return function(...)
    return Future.new {
      args = {...},
      func = func,
      leaf = false,
    }
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
