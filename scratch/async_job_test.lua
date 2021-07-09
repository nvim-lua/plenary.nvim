local async = R "plenary.async"
local async_job = R "plenary.async_job"

async.void(function()
  local pipe = async_job.ChunkPipe:new()
  async_job.AsyncJob.start { "rg", "--files", "/home/tjdevries/", stdout = pipe }

  local count = 1
  for val in pipe:iter() do
    count = count + 1
  end

  print("Count is complete and done", count)
end)()
