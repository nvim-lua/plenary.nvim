-- vim:sw=2
local List = {}

function List:new(tbl)
  if type(tbl) == 'table' then
    local len = #tbl
    local obj = setmetatable(tbl, self)
    obj._len = len
    return obj
  end
  error 'List constructor must be called with table argument'
end

function List.is_list(tbl)
  local meta = getmetatable(tbl) or {}
  return meta == List
end

function List:__index(key)
  if self ~= List then
    local field = List[key]
    if field then return field end
  end
end

function List:__tostring()
  if rawequal(self, List) then return '<List class>' end
  if #self == 0 then return '[]' end
  local result = {'['}
  for _, v in ipairs(self) do
    local repr = tostring(v)
    if type(v) == 'string' then repr = '"' .. repr .. '"' end
    result[#result + 1] = repr
    result[#result + 1] = ', '
  end
  result[#result] = ']'
  return table.concat(result)
end

function List:__eq(other)
  if #self ~= #other then return false end
  for i = 1, #self do if self[i] ~= other[i] then return false end end
  return true
end

function List:__mul(other)
  local result = List {}
  for i = 1, other do result[i] = self end
  return result
end

function List:__len()
  return self._len
end

function List:__concat(other)
  local result = List {}
  for _, v in ipairs(self) do result:push(v) end
  for _, v in ipairs(other) do result:push(v) end
  return result
end

function List:push(other)
  self[#self + 1] = other
  self._len = self._len + 1
end

function List:pop()
  local result = table.remove(self, #self)
  self._len = self._len - 1
  return result
end

function List:insert(idx, other)
  table.insert(self, idx, other)
  self._len = self._len + 1
end

function List:remove(i)
  table.remove(self, i)
  self._len = self._len - 1
end

function List:contains(e)
  for _, v in ipairs(self) do if v == e then return true end end
  return false
end

function List:equal(other)
  return self:__eq(other)
end

function List:deep_equal(other)
  return vim.deep_equal(self, other)
end

function List:slice(a, b)
  return List(vim.list_slice(self, a, b))
end

function List:copy()
  return self:slice(1, #self)
end

function List:deep_copy()
  return vim.deep_copy(self)
end

function List:reverse()
  local n = #self
  local i = 1
  while i < n do
    self[i], self[n] = self[n], self[i]
    i = i + 1
    n = n - 1
  end
  return self
end

-- Iterator stuff

local Iterator = require 'plenary.iterators'

local itermetatable = getmetatable(Iterator:wrap())

local function forward_list_gen(param, state)
  state = state + 1
  local v = param[state]
  if v then return state, v end
end

local function backward_list_gen(param, state)
  state = state - 1
  local v = param[state]
  if v then return state, v end
end

function List:extend(other)
  if type(other) == 'table' and getmetatable(other) == itermetatable then
    for _, v in other do self:push(v) end
  else
    error 'Argument must be an iterator'
  end
end

function List:iter()
  return Iterator.wrap(forward_list_gen, self, 0)
end

function List:riter()
  return Iterator.wrap(backward_list_gen, self, #self + 1)
end

return setmetatable({}, {
  __call = function(_, tbl)
    return List:new(tbl)
  end,
  __index = List,
})
