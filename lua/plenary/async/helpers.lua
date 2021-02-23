local M = {}

VecDeque = {}
VecDeque.__index = VecDeque

function VecDeque.new()
  return setmetatable({first = 0, last = -1}, VecDeque)
end

function VecDeque:pushleft(value)
  local first = self.first - 1
  self.first = first
  self[first] = value
end

function VecDeque:pushright(value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

function VecDeque:popleft()
  local first = self.first
  if first > self.last then return nil end
  local value = self[first]
  self[first] = nil        -- to allow garbage collection
  self.first = first + 1
  return value
end

function VecDeque:is_empty()
  return self.first > self.last
end

function VecDeque:popright()
  local last = self.last
  if self.first > last then return nil end
  local value = self[last]
  self[last] = nil         -- to allow garbage collection
  self.last = last - 1
  return value
end

function VecDeque:len()
  return self.last - self.first
end

M.VecDeque = VecDeque

return M
