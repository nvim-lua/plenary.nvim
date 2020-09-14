RELOAD('plenary')

local ProFi = require('plenary.profile').ProFi

collectgarbage()

ProFi:start()
ProFi:setGetTimeMethod(function() return vim.loop.hrtime() / 1e9 end)
ProFi:checkMemory(0, 'checking')

local s = "hello world this is a longish string. I'm writing more things to make it long"

local iters = 5E5

local y = {}
for i = 1, iters do
  table.insert(y, {s})
end

ProFi:checkMemory(0, 'checking after one')
y = nil

collectgarbage()

ProFi:checkMemory(0, 'checking before two')

local x = {}
for i = 1, iters do
  table.insert(x, {valid = s, display = s, ordinal = s})
end

ProFi:checkMemory(0, 'checking after two')

ProFi:stop()
ProFi:writeReport('./scratch/prof_report.txt')
