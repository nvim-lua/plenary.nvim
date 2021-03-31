-- vim:sw=2
local List = {}

List.__index = List

setmetatable(List, List)

function List:__call(tbl)
  if type(tbl) == 'table' then return setmetatable(tbl, List) end
  return nil
end

function List:__tostring()
  if #self == 0 then return '[]' end
  local result = {'['}
  for _, v in ipairs(self) do
    local repr = tostring(v)
    if type(v) == 'string' then repr = '"' .. repr .. '"' end
    table.insert(result, repr)
    table.insert(result, ', ')
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

function List:__concat(other)
  local result = List {}
  for _, v in ipairs(self) do table.insert(result, v) end
  for _, v in ipairs(other) do table.insert(result, v) end
  return result
end

function List:append(other)
  self[#self + 1] = other
end

function List:index(other)
  for i, v in ipairs(self) do if v == other then return i end end
  return -1
end

function List:pop(i)
  i = i or #self
  return table.remove(self, i)
end

function List:contains(e)
  for _, v in ipairs(self) do if v == e then return true end end
  return false
end

function List:count(e)
  local n = 0
  for _, v in ipairs(self) do if v == e then n = n + 1 end end
  return n
end

function List:equal(other)
  return self:__eq(other)
end

return List
