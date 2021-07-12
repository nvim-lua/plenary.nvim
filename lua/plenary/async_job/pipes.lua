local uv = vim.loop

local Object = require("plenary.class")
local async = require("plenary.async")
local channel = require("plenary.async").control.channel

local M = {}

---@class uv_pipe_t
--- A pipe handle from libuv

---@class BasePipe
---@field super Object: Always available
---@field handle uv_pipe_t: A pipe handle
---@field _closed boolean: Whether the pipe is currently closed or not.
local BasePipe = Object:extend()

function BasePipe:new()
  self._closed = false
end

function BasePipe:close()
  assert(self.handle, "Must have a pipe to close. Otherwise it's weird!")

  if self._closed then return end

  self.handle:read_stop()
  if not self.handle:is_closing() then
    self.handle:close()
  end

  self._closed = true
end


---@class LinesPipe : BasePipe
local LinesPipe = BasePipe:extend()

function LinesPipe:new()
  LinesPipe.super.new(self)
  self.handle = uv.new_pipe(false)
end

function LinesPipe:start()
  self._read_tx, self._read_rx = channel.oneshot()

  self.handle:read_start(function(err, data)
    self.handle:read_stop()

    assert(not err, err)
    self._read_tx(data)
  end)
end

function LinesPipe:iter()
  local _text = nil
  local _index = nil

  local get_next_text = function(previous)
    _index = nil

    local read = self._read_rx()
    if previous == nil and read == nil then
      return
    end

    local text = (previous or '') .. (read or '')
    self:start()

    return text
  end

  local next_value = nil
  next_value = function()
    async.util.scheduler()

    if self._closed then
      return nil
    end

    if _text == nil or (_text == "" and _index == nil) then
      return nil
    end

    local start = _index
    _index = string.find(_text, "\n", _index, true)

    if _index == nil then
      _text = get_next_text(string.sub(_text, start or 1))
      return next_value()
    end

    _index = _index + 1

    return string.sub(_text, start or 1, _index - 2)
  end

  _text = get_next_text()

  return function()
    return next_value()
  end
end


---@class NullPipe : BasePipe
local NullPipe = BasePipe:extend()

function NullPipe:new()
  NullPipe.super.new(self)
  self.start = function() end
  self.close = function() end
end

---@class ChunkPipe : BasePipe
local ChunkPipe = BasePipe:extend()

function ChunkPipe:new()
  ChunkPipe.super.new(self)
  self.handle = uv.new_pipe(false)
end

function ChunkPipe:start()
  self._read_tx, self._read_rx = channel.oneshot()

  self.handle:read_start(function(err, data)
    self.handle:read_stop()

    assert(not err, err)
    self._read_tx(data)
  end)
end

function ChunkPipe:iter()
  return function()
    if self._closed then
      return nil
    end

    return self._read_rx()
  end
end


M.NullPipe = NullPipe
M.LinesPipe = LinesPipe
M.ChunkPipe = ChunkPipe

return M
