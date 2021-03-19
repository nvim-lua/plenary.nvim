---local res = run { "ls", "-A", cwd = "./" }:output():stdout_lines()
---local handle = run { "python", "-i" }
---handle:send("print(5 + 5)")
---local res = await(handle:read_line())
---await(handle:stop())
---local output = await(run { "cat", "path/to/smiley.cat" }:output()):stdout()



local a = require("plenary.async_lib")
local async, await = a.async, a.await
local run = require("plenary.job_future").run

local test = async(function()
  local res = await(run { "echo", [['hello world!']] }:output())
  dump(res)
end)

local cat = async(function()
  local handle = run { "cat", "-", interactive = true }
  await(handle:write("hello world!"))
  dump(await(handle:read_stdout()))
  dump("resulting handle", await(handle:stop()))
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

-- a.run(python())
a.run(test())
