local uv = vim.loop

local log = require("plenary.log")
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

local LinePipe = {}
LinePipe.__index = LinePipe

function LinePipe:new()
  return setmetatable({
    _data = Deque:new(),
    _closed = false,

    _read_tx = nil,
    _read_rx = nil,

    handle = uv.new_pipe(false),
  }, self)
end

function LinePipe:start()
  print("Starting...")

  self._read_tx, self._read_rx = channel.oneshot()

  self.handle:read_start(function(err, data)
    self.handle:read_stop()

    self._read_tx(data)

    if err then return end
    if not data then return end

    self._data:pushright(data)
  end)
end

function LinePipe:close()
  self.handle:read_stop()
  self.handle:close()

  async.util.scheduler()
  self._closed = true
end

function LinePipe:iter()
  local _done = false

  local _value = nil
  local _index = nil

  local needs_new_text = true
  local get_next_text = function()
    if _done then
      return nil
    end

    if not needs_new_text then
      return _value
    end

    needs_new_text = false

    _value = self._data:popleft()
    while _value == nil do
      -- if not self._reading then
      --   self:start()
      -- end
      async.util.scheduler()
      self._read_rx()
      async.util.scheduler()
      _value = self._data:popleft()

      self:start()
      if self._closed and _value == nil then
        _done = true
        break
      end
    end

    return _value
  end

  local next_value = nil
  next_value = function(text)
    if _done then
      return nil
    end

    if not text then
      return nil
    end

    local start = _index
    _index = string.find(text, "\n", _index, true)

    if _index == nil then
      needs_new_text = true

      local next_text = get_next_text() or ''
      return next_value(string.sub(text, start or 1) .. next_text)
    end

    _index = _index + 1

    return string.sub(text, start or 1, _index - 2)
  end

  return function()
    async.util.scheduler()

    local text = get_next_text()
    local value = next_value(text)

    return value
  end
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

function AsyncJob.new(opts)
  local self = setmetatable({}, AsyncJob)

  self.command, self.uv_opts = j_utils.convert_opts(opts)

  self.stdin = opts.stdin or NullPipe:new()
  self.stdout = opts.stdout or NullPipe:new()
  self.stderr = opts.stderr or NullPipe:new()

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
