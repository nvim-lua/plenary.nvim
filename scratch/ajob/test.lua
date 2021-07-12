local uv = vim.loop

local async = R "plenary.async"
local async_job = R "plenary.async_job"
local OneshotLines = R "plenary.async_job.oneshot_lines"

local bufnr = 7
Append = function(...)
  local text = table.concat({...}, "  ")
  if not text then return end

  async.api.nvim_buf_set_lines(bufnr, -1, -1, false, { text })
end

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

async.void(function()
  local start = uv.hrtime()

  local stdout = OneshotLines:new()
  -- local stderr = OneshotLines:new()

  local job = async_job.spawn { "rg", "--files", vim.fn.expand "~", stdout = stdout }
  -- async_job.AsyncJob.start { "./scratch/ajob/line_things.sh", stdout = pipe }

  local text = 0
  for val in stdout:iter_read() do
    text = text + #val

    if text > 1000 then
      print("CANCELLING...")
      -- job:cancel()
      stdout:close()
    end
  end

  async.util.scheduler()
  print("Time Elapsed:", (uv.hrtime() - start) / 1e9, " // Total lines processed:", text)
end)()
