local util = require "plenary.async.util"

return setmetatable({}, {
  __index = function(_, k)
    return function(...)
      -- if we are in a fast event await the scheduler
      if vim.in_fast_event() then
        util.scheduler()
      end

      return vim.fn[k](...)
    end
  end,
})

