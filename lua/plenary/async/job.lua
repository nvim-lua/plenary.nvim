local uv = vim.loop
local if_nil = vim.F.if_nil

local async_lib = require("plenary.async")
local join = async_lib.util.join
local a_uv = async_lib.uv

local Pipe = {}
Pipe.__index = Pipe

function Pipe:new(opts)
  opts = opts or {}

  local ipc = if_nil(opts.ipc, false)

  return setmetatable({
    handle = uv.new_pipe(ipc),
    data = '',
  }, self)
end

function Pipe:read_start(fn)
  -- local scheduled = vim.schedule_wrap(fn)
  local scheduled = fn

  local store = ''

  self.handle:read_start(function(err, data)
    if err then
      print("ERROR")
    end

    if data == nil then
      self.data = store
      return
    end

    store = store .. data
    if scheduled then scheduled(data) end
  end)
end


local AsyncJob = {}
AsyncJob.__index = AsyncJob

function AsyncJob:new(opts)
  return setmetatable({
    command = opts.command,
    args = opts.args,
    cwd = opts.cwd,
  }, self)
end

function AsyncJob:run()
  local handle, pid = nil, nil

  -- local stdin = {} or Pipe:new()
  -- local stdout = Pipe:new()
  -- local stderr = Pipe:new()

  local stdout = uv.new_pipe(false)

  local uv_opts = { 
    cwd = self.cwd,
    args = self.args,
    -- stdio = { stdin.handle, stdout.handle, stderr.handle },
    stdio = { nil, stdout, nil }
  }

  local data, count = '', 0
  handle, pid = uv.spawn(
    self.command,
    uv_opts,
    vim.schedule_wrap(function(code, signal)
      print("Exit:", code, signal, #data, count)

      stdout:read_stop()
      stdout:close()
      handle:close()
    end)
  )

  local f = function(_, d) if not d then return end
    -- data = d
    data = data .. d
    count = count + 1
  end

  -- f = vim.schedule_wrap(f)

  stdout:read_start(f)
  -- stdout:read_start(function(data)
  --   -- print('stdout', data)
  -- end)

  -- stderr:read_start(function(data)
  --   -- print('stderr', data)
  -- end)
end

local M = {}

M.run = function(opts)
  local uv_opts = {}


end

-- function(code, signal)
--   async_lib.void(function()
--     join {
--       a_uv.close(handle),
--       a_uv.close(uv_opts.stdin)
--     }

--     self.dead = true
--     self.exit_tx(code, signal)
--   end)
-- end

AsyncJob:new { command = 'rg', args = { '--files' }, cwd = vim.fn.expand "~" }:run()

return M
