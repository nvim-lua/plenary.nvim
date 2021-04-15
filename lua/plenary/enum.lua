local Enum = {}

function Enum:__eq(other)
  if getmetatable(other) == nil then return false end
  for k, v in pairs(self) do
    if type(k) == 'string' then
      if v ~= other[k] then return false end
    else
      return false
    end
  end
  return true
end

local function make_enum(tbl)
  local result = {}
  local i = 1
  -- Filter out everything that isn't a string, or a table since we only care
  -- about those for enum names/values
  for _, v in ipairs(tbl) do
    if type(v) == 'string' then
      result[v] = i
      i = i + 1
    elseif type(v) == 'table' then
      local name, value = v[1], v[2]
      if vim.tbl_contains(value) then error 'Enum values must not overlap' end
      result[name] = value
      i = value + 1
    end
  end
  vim.tbl_add_reverse_lookup(result)
  return setmetatable(result, Enum)
end

local function is_enum(tbl)
  return getmetatable(tbl) == Enum
end

return setmetatable({is_enum = is_enum, make_enum = make_enum},
                    {__call = make_enum})
