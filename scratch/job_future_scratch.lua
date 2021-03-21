local a = require("plenary.async_lib")
local uv = vim.loop
local async, await = a.async, a.await
local Job = require("plenary.job_future").Job

local fn = async(function()
  local handle = Job { "sleep", "5" }:spawn()
  local res = await(handle:stop())

  dump(res)
  -- dump(res)
  -- assert(res:success())
end)

a.block_on(fn())
