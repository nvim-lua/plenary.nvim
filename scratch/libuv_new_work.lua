local uv = vim.loop

local function work_callback(a, b)
  -- one second of string processing....
  os.execute('sleep 1')
  return a + b
end

local function after_work_callback(c)
  print("The result is: " .. c)
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "-- The Final Result is " .. c})
end

local work = uv.new_work(work_callback, vim.schedule_wrap(after_work_callback))

work:queue(1, 2)
work:queue(1, 2)
work:queue(1, 2)
work:queue(1, 2)
work:queue(1, 2)
work:queue(1, 2)
work:queue(1, 2)
-- The Final Result is 3
