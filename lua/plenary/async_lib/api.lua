local a = require('plenary.async_lib.async')
local async, await = a.async, a.await

return setmetatable({}, {__index = function(t, k)
  return async(function(...)
    await(a.nvim())
    vim.api[k](...)
  end)
end})
