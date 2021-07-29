require('plenary.reload').reload_module('plenary')
local notification_consumer = require('plenary').notification.consumer

notification_consumer.setup()
vim.notify("test")

notification_consumer.list_notifications()
