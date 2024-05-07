---@brief [[
---Operators that are functions.
---This is useful when you want to pass operators to higher order functions.
---Lua has no currying so we have to make a function for each operator.
---@brief ]]

---@class PlenaryOperators
local M = {
  ----------------------------------------------------------------------------
  -- Comparison operators
  ----------------------------------------------------------------------------
  lt = function(a, b)
    return a < b
  end,
  le = function(a, b)
    return a <= b
  end,
  eq = function(a, b)
    return a == b
  end,
  ne = function(a, b)
    return a ~= b
  end,
  ge = function(a, b)
    return a >= b
  end,
  gt = function(a, b)
    return a > b
  end,

  ----------------------------------------------------------------------------
  -- Arithmetic operators
  ----------------------------------------------------------------------------
  ---@param a number
  ---@param b number
  ---@return number
  add = function(a, b)
    return a + b
  end,
  ---@param a number
  ---@param b number
  ---@return number
  div = function(a, b)
    return a / b
  end,
  ---@param a number
  ---@param b number
  ---@return integer
  floordiv = function(a, b)
    return math.floor(a / b)
  end,
  ---@param a number
  ---@param b number
  ---@return integer
  intdiv = function(a, b)
    local q = a / b
    if a >= 0 then
      return math.floor(q)
    else
      return math.ceil(q)
    end
  end,
  ---@param a number
  ---@param b number
  ---@return number
  mod = function(a, b)
    return a % b
  end,
  ---@param a number
  ---@param b number
  ---@return number
  mul = function(a, b)
    return a * b
  end,
  ---@param a number
  ---@return number
  neq = function(a)
    return -a
  end,
  ---@param a number
  ---@return number
  unm = function(a)
    return -a
  end, -- an alias
  ---@param a number
  ---@param b number
  ---@return number
  pow = function(a, b)
    return a ^ b
  end,
  ---@param a number
  ---@param b number
  ---@return number
  sub = function(a, b)
    return a - b
  end,
  ---@param a number
  ---@param b number
  ---@return number
  truediv = function(a, b)
    return a / b
  end,

  ----------------------------------------------------------------------------
  -- String operators
  ----------------------------------------------------------------------------
  ---@param a string
  ---@param b string
  ---@return string
  concat = function(a, b)
    return a .. b
  end,
  ---@param a string
  ---@return integer
  len = function(a)
    return #a
  end,
  ---@param a string
  ---@return integer
  length = function(a)
    return #a
  end, -- an alias

  ----------------------------------------------------------------------------
  -- Logical operators
  ----------------------------------------------------------------------------
  ---@param a boolean
  ---@param b boolean
  ---@return boolean
  land = function(a, b)
    return a and b
  end,
  ---@param a boolean
  ---@param b boolean
  ---@return boolean
  lor = function(a, b)
    return a or b
  end,
  ---@param a boolean
  ---@return boolean
  lnot = function(a)
    return not a
  end,
  ---@param a boolean
  ---@return boolean
  truth = function(a)
    return not not a
  end,
}

return M
