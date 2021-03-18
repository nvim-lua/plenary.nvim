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
  local res = await(run { "ls", cwd = "/home/brian" }:output())
  dump(res)
end)

local cat = async(function()
  local handle = run { "cat", "-", cwd = "/home/brian" }
  await(handle:write("hello world!"))
  -- await(a.utils.sleep(100))
  -- dump(handle)
  dump(await(handle:read_stdout()))
  await(handle:stop())
end)

local python = async(function()
  local handle = run { "python", "-i" }

  -- prelude
  dump(await(handle:read_stderr()))

  -- write 1 + 1
  await(handle:write("1 + 1"))

  dump(await(handle:read_stdout()))

  await(handle:stop())
end)

a.run(python())
