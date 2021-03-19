local Job = require('plenary.job')

local job = Job:new {
  command = 'cat',
  args = {'-'},
}

job:start()
-- this will compeltely block vim
-- whats more it will not even close the process properly
job:shutdown()
