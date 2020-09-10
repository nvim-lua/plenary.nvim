RELOAD('plenary')

local Job = require('plenary.job')

local j = Job:new {
  command = "sleep",
  args = {"10"}
}

j:start()
j:wait(500)
