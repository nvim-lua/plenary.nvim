--[[

-- Looks like making sure that we don't close this job early
https://github.com/wbthomason/packer.nvim/blob/0de1d76a831d647b3a30b2214e3edcd289046dc9/lua/packer/jobs.lua#L49-L62

-- How to schedule a callback??
-- but i think this is still on the same loop...?
https://github.com/wbthomason/packer.nvim/blob/d9c4c890b1a35d80fd4fbbee21114d682bc6a663/lua/packer/display.lua#L34-L75


--]]

local uv = vim.loop

-- print(uv.new_thread(function()
--   return 5
-- end):join())


-- print(uv.version())
-- print(uv.version_string())

local start = uv.hrtime()

local function work_callback(a, b)
  local x = 0
  for i = 1, (a + b) * 1e8 do
    x = i + x
  end

  return a + b
end

local function after_work_callback(c)
  print("The result is: " .. c .. ' ' .. require('luv').hrtime() - start)
end

local work = uv.new_work(work_callback, after_work_callback)

work:queue(1, 2)
work:queue(1, 4)
work:queue(1, 6)
work:queue(2, 6)
work:queue(3, 6)
work:queue(4, 6)
work:queue(5, 6)
work:queue(6, 6)
work:queue(7, 6)
work:queue(8, 6)
work:queue(9, 6)
work:queue(10, 6)
work:queue(11, 6)
print('... done queueing')

-- local async
-- async = uv.new_async(function()
--   local uv = require('luv')
--   for i = 1, 1e10 do
--     i = i + 1
--   end

--   print("async operation ran")
--   async:close()
-- end)

-- async:send()
