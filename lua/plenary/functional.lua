---@class PlenaryFunctional
local f = {}

---@generic T, U
---@param t table<T, U>
---@return { [1]: T, [2]: U }[]
function f.kv_pairs(t)
  local results = {}
  for k, v in pairs(t) do
    table.insert(results, { k, v })
  end
  return results
end

---@generic T, U, V
---@param fun fun(pair: { [1]: T, [2]: U }): V
---@param t table<T, U>
---@return V[]
function f.kv_map(fun, t)
  return vim.tbl_map(fun, f.kv_pairs(t))
end

---@generic T
---@param array T[]
---@param sep? string
---@return string
function f.join(array, sep)
  return table.concat(vim.tbl_map(tostring, array), sep)
end

---@param fn function
---@param n integer
---@param a any
---@param ... any
---@return function
local function bind_n(fn, n, a, ...)
  if n == 0 then
    return fn
  end
  return bind_n(function(...)
    return fn(a, ...)
  end, n - 1, ...)
end

---@param fun function
---@param ... any
---@return function
function f.partial(fun, ...)
  return bind_n(fun, select("#", ...), ...)
end

---@generic T, U
---@param fun fun(k: T, v: U): boolean
---@param iterable table<T, U>
---@return boolean
function f.any(fun, iterable)
  for k, v in pairs(iterable) do
    if fun(k, v) then
      return true
    end
  end

  return false
end

---@generic T, U
---@param fun fun(k: T, v: U): boolean
---@param iterable table<T, U>
---@return boolean
function f.all(fun, iterable)
  for k, v in pairs(iterable) do
    if not fun(k, v) then
      return false
    end
  end

  return true
end

---@generic T, U
---@param val any?
---@param was_nil T
---@param was_not_nil U
---@return T|U
function f.if_nil(val, was_nil, was_not_nil)
  if val == nil then
    return was_nil
  else
    return was_not_nil
  end
end

---@generic T
---@param n integer
---@return fun(...: T): T
function f.select_only(n)
  return function(...)
    local x = select(n, ...)
    return x
  end
end

f.first = f.select_only(1)
f.second = f.select_only(2)
f.third = f.select_only(3)

---@generic T
---@param ... T
---@return T
function f.last(...)
  local length = select("#", ...)
  local x = select(length, ...)
  return x
end

return f
