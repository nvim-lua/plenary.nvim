local a = require('plenary.async_lib2.async')

return setmetatable({}, {__index = function(t, k)
  return function(...)
    -- if we are in a fast event await the scheduler
    if vim.in_fast_event() then
      a.scheduler()
    end

    vim.api[k](...)
  end
end})
