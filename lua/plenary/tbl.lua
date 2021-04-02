local tbl = {}

function tbl.apply_defaults(original, defaults)
  if original == nil then
    original = {}
  end

  original = vim.deepcopy(original)

  for k, v in pairs(defaults) do
    if original[k] == nil then
      original[k] = v
    end
  end

  return original
end

function tbl.copy_one_level(tbl)
  local res = {}
  for k, v in pairs(tbl) do
    res[k] = v
  end
  return res
end

return tbl
