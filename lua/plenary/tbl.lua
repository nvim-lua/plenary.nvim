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

function tbl.map_pairs_inplace(t, func)
  for key, value in pairs(t) do
    t[key] = func(value)
  end
  return t
end

function tbl.map_ipairs_inplace(t, func)
  for key, value in ipairs(t) do
    t[key] = func(value)
  end
  return t
end

return tbl
