local async = require("plenary.async")

local LinePipe = {}
local AsyncJob = {}

local f = async.void(function()
  local line_pipe = LinePipe:new { scheduled = true }

  local _ = AsyncJob:start {
    "rg", "--files",

    cwd = "~",
    stdout = line_pipe,
  }

  for line in line_pipe:iter() do
    -- inside of an schedule_wrap function call
    print(line)
  end
end)

f()
