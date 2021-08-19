local api = vim.api
NOTIFICAION_QUEUE = {}
local M = {}

M.setup = function(consumer)
  vim.notify = function(...)
    local args = { ... }
    table.insert(NOTIFICATION_QUEUE, args[1])
    consumer.notify(...)
  end
end

return M
