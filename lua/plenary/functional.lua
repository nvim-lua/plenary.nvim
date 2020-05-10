package.loaded['plenary.functional'] = nil

local f = {}

f.map = function(fun, iter)
  local results = {}
  for _, v in pairs(iter) do
    table.insert(results, fun(v))
  end

  return results
end

f.partial = function(fun, ...)
  local args = {...}
  return function(...)
    return fun(unpack(args), ...)
  end
end

return f
