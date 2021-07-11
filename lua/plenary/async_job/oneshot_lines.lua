local uv = vim.loop

local async = require("plenary.async")
local channel = async.control.channel

local OneshotLines = {}
OneshotLines.__index = OneshotLines

function OneshotLines:new()
  return setmetatable({
    _closed = false,

    _read_tx = nil,
    _read_rx = nil,

    handle = uv.new_pipe(false),
  }, self)
end

function OneshotLines:start()
  self._read_tx, self._read_rx = channel.oneshot()

  self.handle:read_start(function(err, data)
    self.handle:read_stop()

    assert(not err, err)
    self._read_tx(data)
  end)
end

function OneshotLines:close()
  self.handle:read_stop()
  self.handle:close()

  async.util.scheduler()
  self._closed = true
  Append("Closed!")
end

function OneshotLines:iter()
  local _value = nil
  local _index = nil
  local _await = true

  local get_next_text = function()
    if not _await then
      return _value
    end

    Append("== awaiting value")
    _await = false
    _index = nil

    _value = self._read_rx()
    if _value == nil then
      return
    end

    self:start()
    return _value
  end

  local next_value = nil
  next_value = function(text)
    Append("======== next_value")

    if not text then
      return nil
    end

    local start = _index
    _index = string.find(text, "\n", _index, true)

    Append(vim.inspect(text), start, _index, #text)

    if _index == nil then
      Append("SEARCH:", string.sub(text, start or 1))
      _await = true

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


return OneshotLines
