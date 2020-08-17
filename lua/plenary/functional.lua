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

f.any = function(f, iterable)
  for k, v in pairs(iterable) do
    if f(k, v) then
      return true
    end
  end

  return false
end

f.all = function(f, iterable)
  for k, v in pairs(iterable) do
    if not f(k, v) then
      return false
    end
  end

  return true
end

function f.first(...)
  local x = select(1, ...)
  return x
end

function f.second(...)
  local x = select(2, ...)
  return x
end

function f.third(...)
  local x = select(3, ...)
  return x
end

return f
