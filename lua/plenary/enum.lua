local Enum = {}

local function values(tbl)
  local result = {}
  for k, v in pairs(tbl) do
    if type(v) == 'string' then
      result[k] = true
    elseif type(v) == 'table' then
      local value = v[2]
      if result[value] then return nil, false end
      result[value] = true
    end
  end
  return result, true
end

local function make_enum(tbl)
  local result = {}

  local vals, ok = values(tbl)
  if not ok then error 'Enum specification is malformed' end

  local Variant = {vals = vals}

  local function newVariant(i)
    return setmetatable({__id = i}, Variant)
  end

  function Variant:__index(name)
    return rawget(Variant, name)
  end

  function Variant:__eq(o)
    if self.vals[o] then return self.__id == o end
    if getmetatable(o) == Variant then return self.__id == o.__id end
  end

  function Variant:__add(o)
    return newVariant(self.__id + o)
  end

  function Variant:__tostring()
    return tostring(self.__id)
  end

  function Variant:id()
    return self.__id
  end

  local i = newVariant(1)

  result.__vals = {}

  for _, v in ipairs(tbl) do
    if type(v) == 'string' then
      result[i] = v
      result.__vals[i.__id] = v
      i = i + 1
    elseif type(v) == 'table' and type(v[1]) == 'string' and type(v[2])
        == 'number' then
      i.__id = v[2]
      result[i] = v[1]
      result.__vals[i.__id] = v[1]
      i = i + 1
    end
  end

  vim.tbl_add_reverse_lookup(result)

  return setmetatable(result, Enum)
end

local function is_enum(tbl)
  return getmetatable(tbl) == Enum
end

function Enum:__index(o)
  if type(o) == 'number' then
    local v = self.__vals[o]
    if v then return v end
    error(("No element with value %s in Enum"):format(o))
  end
end

return setmetatable({is_enum = is_enum, make_enum = make_enum}, {
  __call = function(_, tbl)
    return make_enum(tbl)
  end
})
