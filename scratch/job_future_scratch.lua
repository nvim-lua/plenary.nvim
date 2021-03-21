local a = require("plenary.async_lib")
local async, await = a.async, a.await
local Job = require("plenary.job_future").Job

local rg = async(function()
  local handle = Job { "rg", "--vimgrep", ".*", cwd = "/home/brian" }:spawn { raw_read = true }
  for i = 1, 1000000 do
    print(await(handle:raw_read("stdout")))
  end
  await(handle:stop())
end)

local rg_slow = function()
  local Job = require('plenary.job')
  Job:new {
    command = "rg",
    args = {
      "--vimgrep", ".*"
    },
    cwd = "/home/brian",
  }:start()
end

local long_job = async(function()
  local handle = Job { "cat", "-" }:spawn()
  local output = await(handle:stop())
  dump(output)
end)

local long_job_slow = function()
  local Job = require('plenary.job')
  local job = Job:new {
    command = "cat",
    args = {
      "-",
    },
  }
  job:start()
  job:shutdown()
end

-- rg_slow()
a.run(rg())
-- a.run(long_job())
-- long_job_slow()
