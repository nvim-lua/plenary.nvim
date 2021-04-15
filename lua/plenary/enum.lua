local Enum = {}

setmetatable(Enum, Enum)

function Enum:__call(tbl)
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
      result[name] = value
      i = value + 1
    end
  end
  return vim.tbl_add_reverse_lookup(result)
end

function Enum.is_enum(tbl)
  for k, v in ipairs(tbl) do
    if tbl[k] ~= v or tbl[v] ~= k then return false end
    return true
  end
end

return Enum
