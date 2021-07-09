local uv = vim.loop

local async = require("plenary.async")
local a_util = async.util
local a_uv = async.uv

local Deque = require('plenary.async.structs').Deque
local iter_lines = require('plenary.iterators').lines

local stdout = uv.new_pipe(false)

local handle = nil
handle = uv.spawn(
  "rg", {
    args = { "--files" },
    cwd = vim.fn.expand "~/",
    stdio = { nil, stdout, nil },
  }, function(code, signal)
    print(code, signal)

    stdout:read_stop()
    stdout:close()
    handle:close()
  end
)

local f = async.void(function()
  local data = Deque.new()
  stdout:read_start(function(_, d)
    if not d then
      return
    end

    -- table.insert(data, d)
    data:pushright(d)
  end)

  while not stdout:is_closing() do
    a_util.scheduler()
  end
  a_util.scheduler()

  local start = uv.hrtime()

  local text = data:popleft()

  local starting_new_text = true

  local matcher = nil
  local index, line = nil, nil

  local count = 0
  local get_next_text = function()
    print("... Getting new text", count)
    count = count + 1

    text = data:popleft()
    starting_new_text = true
  end

  local get_new_matcher = function()
    if starting_new_text then
      starting_new_text = false

      matcher = iter_lines(text)
    end
  end

  local data_iter

  data_iter = function()
    if text == nil then
      get_next_text()

      -- TODO This is where you need to wait for more stdout
      -- if we wanted to do it that way
      if text == nil then
        return
      end
    end

    get_new_matcher()
    index, line = matcher(nil, index)

    if not line and not data:is_empty() then
      text = nil
      return data_iter()
    end

    return index, line
  end

  local iterated = 0
  for i, v in data_iter do
    iterated = iterated + 1

    if i < 100 then
      print("NEXT:", i, v)
    end

    if STOP then 
      print("STOPPED")
      return
    end
  end

  print("Took:", (uv.hrtime() - start) / 1e9, "Completed: ", iterated)
end)

STOP = false
f()

--[[

AsyncJob -> returns handle
LineAsyncJob -> :iter(), lines of strings

LineAsyncJob:iter()
  local state = {...}
  pipe:read_start(function(err, data)
    pipe:read_stop()
    if data == nil then return end

    next = ...
  end)

-- inside some async function context
for line in LineAsyncJob { "rg", "--files", cwd = "...", scheduled = true, }:iter() do
  if cancelled then
    return
  end
end

--]]
