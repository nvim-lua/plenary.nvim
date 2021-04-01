local v = {}

function v.nth(n, ...)
  local x = select(n, ...)
  return x
end

function v.select_only(n)
  return function(...)
    return v.nth(n, ...)
  end
end

v.first = v.select_only(1)
v.second = v.select_only(2)
v.third = v.select_only(3)

function v.len(...)
  return select('#', ...)
end

function v.last(...)
  local len = v.len(...)
  local x = select(len, ...)
  return x
end

---flips binary arguments
function v.flip(...)
  assert(v.len(...) == 2, "Args must be of length 2")
  return v.rotate(...)
end

---rotates arguments to the left
function v.rotate(...)
  local first = v.first(...)
  return select(2, ...), first
end

function v.double(...)
  return ..., ...
end

function v.duplicate(n, ...)
  assert(n > 0, "n must be greater than 0")
  if n == 1 then return ... end
  return ..., v.duplicate(n - 1, ...)
end

return v
