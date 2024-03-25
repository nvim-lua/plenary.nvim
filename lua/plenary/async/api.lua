local util = require "plenary.async.util"

---@type table<string, PlenaryAsyncFunction>
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
