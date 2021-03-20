---local res = run { "ls", "-A", cwd = "./" }:output():stdout_lines()
---local handle = run { "python", "-i" }
---handle:send("print(5 + 5)")
---local res = await(handle:read_line())
---await(handle:stop())
---local output = await(run { "cat", "path/to/smiley.cat" }:output()):stdout()



local a = require("plenary.async_lib")
local uv = vim.loop
local async, await = a.async, a.await
local run = require("plenary.job_future").run

local test = async(function()
  local res = await(run { "echo", [['hello world!']] }:output())
  dump(res)
end)

local no_close = async(function()
  local res = run { "echo", [['hello world!']] }
end)

local cat = async(function()
  local handle = run { "cat", "-", interactive = true }
  await(handle:write("hello world!"))
  await(handle:read_stdout())
  await(handle:stop())
end)

local python = async(function()
  local handle = run { "python", "-i", interactive = true }

  -- prelude
  dump(await(handle:read_stderr()))

  await(handle:write("1 + 1"))

  dump(await(handle:read_stdout()))

  local res = await(handle:stop())
  dump("res", res)
end)

local long_job = async(function()
  local handle = run { "sleep", "5" }
  local res = await(handle:stop())
  dump(res)
end)

local concurrent = function()
  local jobs = {}
  for i = 1, 200 do jobs[i] = cat() end
  a.run_all(jobs)
end

local another = function()
  uv.spawn("sleep", {args = {"1"}}, function(status, signal)
    print('The status was:', status)
    print('The signal was:', signal)
  end)
end

-- a.run(cat())
