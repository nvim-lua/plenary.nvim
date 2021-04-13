local Enum = {}

setmetatable(Enum, Enum)

function Enum:__call(tbl)
  local result = {}
  for i, v in ipairs(tbl) do
    if type(v) ~= 'string' then
      error 'Enum names must be strings'
      return nil
    end
    result[v] = i
  end
  return vim.tbl_add_reverse_lookup(result)
end

function Enum.is_enum(tbl)
  for i, v in ipairs(tbl) do
    if tbl[i] ~= v or tbl[v] ~= i then return false end
  end
  return true
end

return Enum
