local uv = vim.loop

local run_large_test = function(f, e)
  local start = uv.hrtime()

  local stdout = uv.new_pipe(false)

  local handle = nil
  handle = uv.spawn(
    "rg", {
      args = { "--files" },
      cwd = vim.fn.expand "~/sourcegraph/",
      stdio = { nil, stdout, nil },
    }, function(code, signal)
      local elapsed = (uv.hrtime() - start) / 1e9

      print("Time Elapsed: ", elapsed)
      if e then e() end

      stdout:read_stop()
      stdout:close()
      handle:close()
    end
  )

  -- vim.defer_fn(function()
  stdout:read_start(function(_, d)
    if not d then return end
    f(d)
  end)
  -- end, 3000)
end


-- run_large_test(function() end)

-- local data = ''
-- run_large_test(function(_, d) data = d end)

-- local count = 0
-- run_large_test(function() count = count + 1 end, function() print(count) end)

-- local data = ''
-- run_large_test(function(d) data = data .. d end)

local data = {}
local len = 1
local count = 0
local finished = false
run_large_test(function(d)
  count = count + 1
  data[len] = d
  len = len + 1
end, function()
  finished = true
  print("Count:", count)
end)

-- local idle = uv.new_idle()
-- idle:start(vim.schedule_wrap(function()
--   print("Yo, I'm idling now...", #data)
-- end))

-- vim.defer_fn(function() idle:close() end, 2000)

--[[

spawn a job
now you have handle
you do:
for entry in handle:iter() do

end



--]]
