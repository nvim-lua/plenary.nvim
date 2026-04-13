local util = require "plenary.async.util"

---@alias PlenaryAsyncApi table<string, PlenaryAsyncFunction>

---@type PlenaryAsyncApi
return setmetatable({}, {
  __index = function(t, k)
    return function(...)
      -- if we are in a fast event await the scheduler
      if vim.in_fast_event() then
        util.scheduler()
      end

      return vim.api[k](...)
    end
  end,
})
