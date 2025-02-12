local a = require "plenary.async.async"
local vararg = require "plenary.vararg"
-- local control = a.control
local control = require "plenary.async.control"
local channel = control.channel

---@class PlenaryAsyncUtil
local M = {}

---@param timeout integer Number of milliseconds to wait before calling `fn`
---@param callback function Callback to call once `timeout` expires
local defer_swapped = function(timeout, callback)
  vim.defer_fn(callback, timeout)
end

---Sleep for milliseconds
M.sleep = a.wrap(defer_swapped, 2) --[[@as async fun(timeout: integer): nil]]

---This will COMPLETELY block neovim
---please just use a.run unless you have a very special usecase
---for example, in plenary test_harness you must use this
---@param async_function PlenaryAsyncFunction
---@param timeout? integer Stop blocking if the timeout was surpassed. Default 2000.
M.block_on = function(async_function, timeout)
  async_function = M.protected(async_function)

  local stat
  local ret = {}

  a.run(async_function, function(stat_, ...)
    stat = stat_
    ret = { ... }
  end)

  vim.wait(timeout or 2000, function()
    return stat ~= nil
  end, 20, false)

  if stat == false then
    error(string.format("Blocking on future timed out or was interrupted.\n%s", unpack(ret)))
  end

  return unpack(ret)
end

---@see M.block_on
---@param async_function PlenaryAsyncFunction
---@param timeout? integer
M.will_block = function(async_function, timeout)
  return function()
    M.block_on(async_function, timeout)
  end
end

---@param async_fns PlenaryAsyncFunction[]
---@return table
M.join = function(async_fns)
  local len = #async_fns
  local results = {}
  if len == 0 then
    return results
  end

  local done = 0

  local tx, rx = channel.oneshot()

  for i, async_fn in ipairs(async_fns) do
    assert(type(async_fn) == "function", "type error :: future must be function")

    local cb = function(...)
      results[i] = { ... }
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

---Returns a result from the future that finishes at the first
---* param async_functions table: The futures that you want to select
---@param async_functions PlenaryAsyncFunction[]
---@param step fun(...: any): ...: any
M.run_first = a.wrap(function(async_functions, step)
  local ran = false

  for _, async_function in ipairs(async_functions) do
    assert(type(async_function) == "function", "type error :: future must be function")

    local callback = function(...)
      if not ran then
        ran = true
        step(...)
      end
    end

    async_function(callback)
  end
end, 2) --[[@as async fun(async_functions: PlenaryAsyncFunction[]): ...]]

---Returns a result from the functions that finishes at the first
---@param funcs function[]: The async functions that you want to select
---@return ...
M.race = function(funcs)
  ---@type PlenaryAsyncFunction[]
  local async_functions = vim.tbl_map(function(func)
    return function(callback)
      a.run(func, callback)
    end
  end, funcs)
  return M.run_first(async_functions)
end

---@param async_fns PlenaryAsyncFunction[]
---@param callback fun(...: any): ...: any
M.run_all = function(async_fns, callback)
  a.run(function()
    M.join(async_fns)
  end, callback)
end

---@async
---@param leaf PlenaryAsyncLeaf|function
---@param ... any
---@return boolean, ...
function M.apcall(leaf, ...)
  local nargs = a.get_leaf_function_argc(leaf)
  if nargs then
    local tx, rx = channel.oneshot()
    local stat, ret = pcall(leaf, vararg.rotate(nargs, tx, ...))
    if not stat then
      return stat, ret
    else
      return stat, rx()
    end
  else
    return pcall(leaf, ...)
  end
end

---comment
---@param async_fn PlenaryAsyncFunction
---@return PlenaryAsyncFunction
function M.protected(async_fn)
  return function()
    return M.apcall(async_fn)
  end
end

---An async function that when called will yield to the neovim scheduler to be able to call the api.
M.scheduler = a.wrap(vim.schedule, 1) --[[@as async fun(): nil]]

return M
