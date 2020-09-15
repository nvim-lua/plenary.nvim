RELOAD('plenary')

local Job = require('plenary.job')

local job = Job:new {
  command = 'ls',
  args = {'-l'},
}

local start = vim.fn.reltime()
print(vim.inspect(#job:sync()))
print(vim.fn.reltimestr(vim.fn.reltime(start)))
-- print(vim.inspect(job:sync()))
