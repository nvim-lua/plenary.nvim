local api = vim.api
local M = {}

M.notification_store = {} -- place to store all notifications
M.actions = {} -- actions that can be done to a notifcation

local random = math.random
local function uuid()
  local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function (c)
      local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
      return string.format('%x', v)
  end)
end

M.setup = function(consumer, opts)
  if consumer.setup then pcall(consumer.setup) end

  vim.notify = function(message)
    local notification = {
      message = message,
    }
    M.notification_store[uuid()] = notification
  end
end

M.actions.dismiss = function(notifcation_id)
  local i = (function()
    for _i, _ in ipairs(M.notification_store) do
      if _i == notifcation_id then
        return _i
      end
    end
  end)()

  if i == nil then
    error("invalid notification id")
  end

  table.remove(M.notification_store, i)
end

return M
