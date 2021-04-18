local Enum = {}

local function make_enum(tbl)
  local enum = {}

  local Variant = {}
  Variant.__index = Variant

  local function newVariant(i)
    return setmetatable({_id = i}, Variant)
  end

  -- we don't need __eq because the __eq metamethod will only ever be invoked when they both have the same metatable

  function Variant:__lt(o)
    return self._id < o._id
  end

  function Variant:__gt(o)
    return self._id > o._id
  end

  function Variant:__tostring()
    return tostring(self._id)
  end

  function Variant:id()
    return self._id
  end

  local function find_next_idx(enum, i)
    while true do
      if not enum[i] then return i end
      i = i + 1
    end
  end

  local i = 1

  for _, v in ipairs(tbl) do
    if type(v) == 'string' then
      local name = v
      local idx = find_next_idx(enum, i)
      enum[idx] = name
      if enum[name] then error('Duplicate enum name') end
      enum[name] = newVariant(idx)
      i = idx
    elseif type(v) == 'table' and type(v[1]) == 'string' and type(v[2])
        == 'number' then
      local name = v[1]
      local idx = v[2]
      if enum[idx] then error('Overlapping indices') end
      enum[idx] = name
      if enum[name] then error('Duplicate name') end
      enum[name] = newVariant(idx)
      i = idx
    else
      error('Invalid way to specify an enum variant')
    end
  end

  return setmetatable(enum, Enum)
end

Enum.__index = function(table, key)
  if Enum[key] then return Enum[key] end
  error('Invalid enum key ' .. tostring(key))
end

function Enum:has_key(key)
  if rawget(self, key) then return true end
  return false
end

local function is_enum(tbl)
  return getmetatable(tbl) == Enum
end

return setmetatable({is_enum = is_enum, make_enum = make_enum}, {
  __call = function(_, tbl)
    return make_enum(tbl)
  end,
})
