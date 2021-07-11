local uv = vim.loop

local async = R "plenary.async"
local async_job = R "plenary.async_job"
local OneshotLines = R "plenary.async_job.oneshot_lines"

local bufnr = 7
local append = function(text)
  if not text then return end

  async.api.nvim_buf_set_lines(bufnr, -1, -1, false, { text })
end

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

async.void(function()
  local start = uv.hrtime()

  local pipe = OneshotLines:new()
  -- async_job.AsyncJob.start { "rg", "--files", "/home/tjdevries/", stdout = pipe }
  async_job.AsyncJob.start { "./scratch/ajob/line_things.sh", stdout = pipe }

  local count = 1
  for val in pipe:iter() do
    count = count + 1
    -- if count % 1000 == 0 then
      append(val)
    -- end
  end

  print("Time Elapsed:", (uv.hrtime() - start) / 1e9, " // Total lines processed:", count)
end)()
