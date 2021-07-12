local uv = vim.loop

local log = require("plenary.log")
local async = require("plenary.async")
local channel = async.control.channel

local Deque = require('plenary.async.structs').Deque
local NullPipe = require('plenary.async_job.pipes').NullPipe

local j_utils = require('plenary.async_job.util')

local M = {}

local AsyncJob = {}
AsyncJob.__index = AsyncJob

-- function AsyncJob:new(opts)
--   return setmetatable({}, self)
-- end

function AsyncJob.new(opts)
  local self = setmetatable({}, AsyncJob)

  self.command, self.uv_opts = j_utils.convert_opts(opts)

  self.stdin = opts.stdin or NullPipe()
  self.stdout = opts.stdout or NullPipe()
  self.stderr = opts.stderr or NullPipe()

  self.uv_opts.stdio = {
    self.stdin.handle,
    self.stdout.handle,
    self.stderr.handle,
  }

  return self
end

function AsyncJob:_for_each_pipe(f, ...)
  for _, pipe in ipairs({self.stdin, self.stdout, self.stderr}) do
    f(pipe, ...)
  end
end

function AsyncJob:start()
  self:_for_each_pipe(function(p) p:start() end)
end

function AsyncJob:close()
  self:_for_each_pipe(function(p) p:close() end)
  self.handle:close()

  log.debug("[async_job] closed")
end

M.ChunkPipe = ChunkPipe
M.LinePipe = LinePipe

M.spawn = function(opts)
  local self = AsyncJob.new(opts)

  self.handle = uv.spawn(self.command, self.uv_opts, async.void(function()
    self:close()
  end))

  self:start()

  return self
end

return M
