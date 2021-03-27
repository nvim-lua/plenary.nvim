local M = {}

Deque = {}
Deque.__index = Deque

---@class Deque
---A double ended queue
---
---@return Deque
function Deque.new()
  return setmetatable({first = 0, last = -1}, Deque)
end

function Deque:pushleft(value)
  local first = self.first - 1
  self.first = first
  self[first] = value
end

function Deque:pushright(value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

function Deque:popleft()
  local first = self.first
  if first > self.last then return nil end
  local value = self[first]
  self[first] = nil        -- to allow garbage collection
  self.first = first + 1
  return value
end

function Deque:is_empty()
  return self.first > self.last
end

function Deque:popright()
  local last = self.last
  if self.first > last then return nil end
  local value = self[last]
  self[last] = nil         -- to allow garbage collection
  self.last = last - 1
  return value
end

function Deque:len()
  return self.last - self.first
end

M.Deque = Deque

return M
