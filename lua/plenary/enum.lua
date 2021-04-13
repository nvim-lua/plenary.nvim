local Enum = {}

setmetatable(Enum, Enum)

function Enum:__call(tbl)
  local result = {}
  -- Filter out everything that isn't a string, since we only care about
  -- those for enum names
  for k, v in ipairs(tbl) do if type(v) == 'string' then result[k] = v end end
  return vim.tbl_add_reverse_lookup(result)
end

function Enum.is_enum(tbl)
  for k, v in ipairs(tbl) do
    if tbl[k] ~= v or tbl[v] ~= k then return false end
    return true
  end
end

return Enum
