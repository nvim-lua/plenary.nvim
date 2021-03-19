local Job = require('plenary.job')

local function first()
  local job = Job:new {
    command = 'cat',
    args = {'-'},
  }

  job:start()

  -- this will compeltely block vim
  -- whats more it will not even close the process properly
  job:shutdown()
end

local function second()
  local job = Job:new {
    command = 'python',
    args = {'-i'},
  }

  job:start()
  job:shutdown()
end

second()
