require('plenary.reload').reload_module('plenary')

local Job = require('plenary.job')

local run_manual = true
local run_larger = true

if run_manual then
  local results = {}

  local job = Job:new {
    -- writer = "hello\nword\nthis is\ntj",
    command = 'cat',

    on_stdout = function(_, data)
      table.insert(results, data)
    end,
  }

  job:start()
  -- vim.wait(10, function() return false end)
  job:send("hello\nwor")
  -- vim.wait(10, function() return false end)
  job:send("ld\nthis is tj\n")
  job:send("\n\n\nwow")
  -- vim.wait(10, function() return false end)
  job:shutdown()

  -- assert(#results > 0, 'should have results by now')
  print(vim.inspect(results))
  if vim.inspect(results) ~= vim.inspect(job:result()) then
    print("FAILED")
    print(vim.inspect(results))
    print(vim.inspect(job:result()))
  end
end

local ls_results = {}

local ls_job = Job:new {
  command = 'ls',
  args = {'-l'},

  on_stdout = function(_, data)
    table.insert(ls_results, data)
  end,
}

local ls_synced = ls_job:sync()
if vim.inspect(ls_synced) ~= vim.inspect(ls_results) then
  print(vim.inspect(ls_synced))
  print(vim.inspect(ls_results))
end

assert(vim.inspect(ls_synced) == vim.inspect(ls_results))
assert(ls_synced[#ls_synced] ~= '')

if run_larger then
  local system_result = vim.fn.system('fdfind')
  print(#system_result)

  local fd_results = {}

  local find_job = Job:new {
    command = 'fdfind',

    on_stdout = function(err, data) table.insert(fd_results, data) end,
  }

  local start = vim.fn.reltime()
  local find_result = find_job:sync()
  print("TIME", vim.fn.reltimestr(vim.fn.reltime(start)))
  print(#find_result, #table.concat(find_result, "\n"))
  print(#fd_results, #table.concat(fd_results, "\n"))
  print(#system_result, #table.concat(fd_results, "\n"))

  local assert = require('luassert')
  assert.are.same(system_result, table.concat(fd_results, "\n") .. "\n")
end

print("Nice work!")
