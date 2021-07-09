local uv = vim.loop

local async = require("plenary.async")
local channel = async.control.channel

local Deque = require('plenary.async.structs').Deque

local j_utils = require('plenary.async_job.util')

local M = {}

local NullPipe = {}
NullPipe.__index = NullPipe

function NullPipe:new()
  return setmetatable({
    start = function() end,
    close = function() end,
  }, self)
end

local ChunkPipe = {}
ChunkPipe.__index = ChunkPipe

function ChunkPipe:new()
  return setmetatable({
    _data = Deque:new(),

    closed = false,
    handle = uv.new_pipe(false),
  }, self)
end

function ChunkPipe:start()
  self.handle:read_start(function(err, data)
    if err then return end
    if not data then return end

    -- table.insert(self._data, data)
    self._data:pushright(data)
  end)
end

-- function ChunkPipe:finish()
--   if self.on_exit then
--     self:on_exit()
--   end
-- end

function ChunkPipe:close()
  self.handle:read_stop()
  async.uv.close(self.handle)

  async.util.scheduler()
  self.closed = true
end

function ChunkPipe:iter()
  return function()
    local value = self._data:popleft()
    while value == nil do
      async.util.scheduler()
      value = self._data:popleft()

      if self.closed and value == nil then
        break
      end
    end

    return value
  end
end

local AsyncJob = {}
AsyncJob.__index = AsyncJob

-- function AsyncJob:new(opts)
--   return setmetatable({}, self)
-- end

function AsyncJob.start(opts)
  local self = setmetatable({}, AsyncJob)

  local command, uv_opts = j_utils.convert_opts(opts)
  uv_opts.stdio = {}

  -- TODO: Other handles
  -- TODO: NullPipe, just implements all the stuff, but doesn't do anything
  local stdout = opts.stdout or NullPipe:new()
  uv_opts.stdio[2] = stdout.handle

  self.handle = uv.spawn(command, uv_opts, async.void(function()
    stdout:close()
    self.handle:close()
  end))

  stdout:start()
end


M.AsyncJob = AsyncJob
M.ChunkPipe = ChunkPipe

return M
