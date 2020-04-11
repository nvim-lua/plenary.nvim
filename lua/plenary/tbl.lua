local tbl = {}

function tbl.apply_defaults(original, defaults)
  original = vim.deepcopy(original)

  for k, v in ipairs(defaults) do
    if original[k] == nil then
      original[k] = v
    end
  end

  return original
end

return tbl
