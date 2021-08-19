local api = vim.api
local M = {}

--- WHAT THIS REQUIRES
--- consuemr to should have a setup method
--- if the consuemr has a queue behavior, then consumer.queue should be a table
--- that acts as the queue
M.has_queue_behavior = false
M.setup = function(consumer)
  if consumer.queue then
    M.has_queue_behavior = true
  end

  if M.has_queue_behavior then
    vim.notify = function(...)
      local args = { ... }
      table.insert(consumer.queue, args[1])
      consumer.notify(...)
    end
  else
    vim.notify = function(...)
      consumer.notify(...)
    end
  end
end

M.example_consumer = {}

return M
