require('plenary.reload').reload_module('plenary')

local api = vim.api
local notifications = require('plenary').notifications

-- example consumer
local consumer = {}

consumer.queue = {}

consumer.notify = function(...)
  local messages = { ... }
  for _, message in pairs(messages) do
    table.insert(NOTIFICAION_QUEUE, message)
    print(vim.inspect(string.format("NOTIFICATION: %s", message)))
  end
end

consumer.setup = function()
  vim.notify = consumer.notify
end

consumer.list_notifications = function()
  local win_info = float.percentage_range_window(0.5, 0.5)
  local lines = {}

  for i, notification in pairs(NOTIFICAION_QUEUE) do
    table.insert(lines, string.format("%i: %s", i, notification))
  end

  api.nvim_buf_set_lines(win_info.bufnr, 0, -1, false, lines)
end

notifications.setup(consumer)
