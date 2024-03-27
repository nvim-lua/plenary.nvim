--- I like context managers for Python
--- I want them in Lua.

---@class PlenaryContextManager
local context_manager = {}

---@class PlenaryContextManagerObject
---@field enter fun(self: PlenaryContextManagerObject): any
---@field exit fun(self: PlenaryContextManagerObject)

---@generic T, U
---@param obj function|PlenaryContextManagerObject|thread
---@param callable fun(arg: T): U?
---@return U?
function context_manager.with(obj, callable)
  -- Wrap functions for people since we're nice
  if type(obj) == "function" then
    obj = coroutine.create(obj)
  end

  if type(obj) == "thread" then
    local ok, context = coroutine.resume(obj)
    assert(ok, "Should have yielded in coroutine.")

    local succeeded, result = pcall(callable, context)

    local done, _ = coroutine.resume(obj)
    assert(done, "Should be done")

    local no_other = not coroutine.resume(obj)
    assert(no_other, "Should not yield anymore, otherwise that would make things complicated")

    assert(succeeded, result)
    return result
  else
    assert(obj.enter)
    assert(obj.exit)

    -- TODO: Callable can be string for vimL function or a lua callable
    local context = obj:enter()
    local succeeded, result = pcall(callable, context)
    obj:exit()

    assert(succeeded, result)
    return result
  end
end
---If string, used as io.open(filename). Else, should be a table with `filename` as an attribute
---@param filename string|{ filename: string }
---@param mode? openmode
---@return thread
function context_manager.open(filename, mode)
  if type(filename) == "table" and filename.filename then
    filename = filename.filename
  end

  local file_io = assert(io.open(filename --[[@as string]], mode))

  return coroutine.create(function()
    coroutine.yield(file_io)

    file_io:close()
  end)
end

return context_manager
