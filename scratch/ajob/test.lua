local uv = vim.loop

local async = R "plenary.async"
local async_job = R "plenary.async_job"
local async_pipes = R "plenary.async_job.pipes"

local LinesPipe = async_pipes.LinesPipe
local ChunkPipe = async_pipes.ChunkPipe

local bufnr = 7
Append = function(...)
  local text = table.concat({...}, "  ")
  if not text then return end

  async.api.nvim_buf_set_lines(bufnr, -1, -1, false, { text })
end
-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

async.void(function()
  local start = uv.hrtime()

  local chunk = true

  local stdout 
  if chunk then
    stdout = ChunkPipe()
  else
    stdout = LinesPipe()
  end

  local _ = async_job.spawn { "rg", "--files", vim.fn.expand "~", stdout = stdout }
  -- async_job.AsyncJob.start { "./scratch/ajob/line_things.sh", stdout = pipe }

  local text = 0
  for val in stdout:iter() do
    text = text + #val

    if text > 1000 then
      print("CANCELLING...")
      stdout:close()
    end
  end

  async.util.scheduler()
  print("Time Elapsed:", (uv.hrtime() - start) / 1e9, " // Total lines processed:", text)
end)()
