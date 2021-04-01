-- Adaptation of luafun for neovim
local co = coroutine

--------------------------------------------------------------------------------
-- Tools
--------------------------------------------------------------------------------
local exports = {}

local Iterator = {}
Iterator.__index = Iterator

---Makes a for loop work
function Iterator:__call(param, state)
  return self.gen(param, state)
end

function Iterator:__tostring()
  return '<iterator>'
end

-- A special hack for zip/chain to skip last two state, if a wrapped iterator
-- has been passed
local numargs = function(...)
  local n = select('#', ...)
  if n >= 3 then
    -- Fix last argument
    local it = select(n - 2, ...)
    if type(it) == 'table' and getmetatable(it) == Iterator and
      it.param == select(n - 1, ...) and it.state == select(n, ...) then
      return n - 2
    end
  end
  return n
end

local return_if_not_empty = function(state_x, ...)
  if state_x == nil then
    return nil
  end
  return ...
end

local call_if_not_empty = function(fun, state_x, ...)
  if state_x == nil then
    return nil
  end
  return state_x, fun(...)
end

--------------------------------------------------------------------------------
-- Basic Functions
--------------------------------------------------------------------------------
local nil_gen = function(_param, _state)
  return nil
end

local ipairs_gen = ipairs({}) -- get the generating function from ipairs

local pairs_gen = pairs({}) -- get the generating function from pairs

local map_gen = function(map, key)
  key, value = pairs_gen(map, key)
  return key, key, value
end

local string_gen = function(param, state)
  state = state + 1
  if state > #param then
    return nil
  end
  local r = string.sub(param, state, state)
  return state, r
end

local rawiter = function(obj, param, state)
  assert(obj ~= nil, "invalid iterator")

  if type(obj) == "table" then
    local mt = getmetatable(obj);

    if mt ~= nil then
      if mt == Iterator then
        return obj.gen, obj.param, obj.state
      end
    end

    if vim.tbl_islist(obj) then
      return ipairs(obj)
    else
      -- hash
      return map_gen, obj, nil
    end
  elseif (type(obj) == "function") then
    return obj, param, state
  elseif (type(obj) == "string") then
    if #obj == 0 then
      return nil_gen, nil, nil
    end

    return string_gen, obj, 0
  end

  error(string.format('object %s of type "%s" is not iterable', obj, type(obj)))
end

local function wrap(gen, param, state)
  return setmetatable({
    gen = gen,
    param = param,
    state = state
  }, Iterator), param, state
end

local unwrap = function(self)
    return self.gen, self.param, self.state
end

local iter = function(obj, param, state)
  return wrap(rawiter(obj, param, state))
end

exports.iter = iter
exports.wrap = wrap
exports.unwrap = unwrap

function Iterator:for_each(fn)
  local param, state = self.param, self.state
  repeat
    state = call_if_not_empty(fn, self.gen(param, state))
  until state == nil
end

function Iterator:stateful()
  local gen, param, state = self.gen, self.param, self.state

  local function set_state(...)
    state = ...
  end

  return function()
    return call_if_not_empty(set_state, gen(param, state))
  end
end
--------------------------------------------------------------------------------
-- Generators
--------------------------------------------------------------------------------
local range_gen = function(param, state)
  local stop, step = param[1], param[2]
  state = state + step
  if state > stop then
    return nil
  end
  return state, state
end

local range_rev_gen = function(param, state)
  local stop, step = param[1], param[2]
  state = state + step
  if state < stop then
    return nil
  end
  return state, state
end

local range = function(start, stop, step)
  if step == nil then
    if stop == nil then
      if start == 0 then
        return nil_gen, nil, nil
      end
      stop = start
      start = stop > 0 and 1 or -1
    end
    step = start <= stop and 1 or -1
  end

  assert(type(start) == "number", "start must be a number")
  assert(type(stop) == "number", "stop must be a number")
  assert(type(step) == "number", "step must be a number")
  assert(step ~= 0, "step must not be zero")

  if (step > 0) then
    return wrap(range_gen, {stop, step}, start - step)
  elseif (step < 0) then
    return wrap(range_rev_gen, {stop, step}, start - step)
  end
end
exports.range = range

local duplicate_table_gen = function(param_x, state_x)
  return state_x + 1, unpack(param_x)
end

local duplicate_fun_gen = function(param_x, state_x)
  return state_x + 1, param_x(state_x)
end

local duplicate_gen = function(param_x, state_x)
  return state_x + 1, param_x
end

local duplicate = function(...)
  if select('#', ...) <= 1 then
    return wrap(duplicate_gen, select(1, ...), 0)
  else
    return wrap(duplicate_table_gen, {...}, 0)
  end
end
exports.duplicate = duplicate

local tabulate = function(fun)
  assert(type(fun) == "function")
  return wrap(duplicate_fun_gen, fun, 0)
end
exports.tabulate = tabulate

local zeros = function()
  return wrap(duplicate_gen, 0, 0)
end
exports.zeros = zeros

local ones = function()
  return wrap(duplicate_gen, 1, 0)
end
exports.ones = ones

local rands_gen = function(param_x, _state_x)
  return 0, math.random(param_x[1], param_x[2])
end

local rands_nil_gen = function(_param_x, _state_x)
  return 0, math.random()
end

local rands = function(n, m)
  if n == nil and m == nil then
    return wrap(rands_nil_gen, 0, 0)
  end
  assert(type(n) == "number", "invalid first arg to rands")
  if m == nil then
    m = n
    n = 0
  else
    assert(type(m) == "number", "invalid second arg to rands")
  end
  assert(n < m, "empty interval")
  return wrap(rands_gen, {n, m - 1}, 0)
end
exports.rands = rands
--------------------------------------------------------------------------------
-- Transformations
--------------------------------------------------------------------------------
local map_gen = function(param, state)
    local gen_x, param_x, fun = param[1], param[2], param[3]
    return call_if_not_empty(fun, gen_x(param_x, state))
end

function Iterator:map(fn)
  return wrap(map_gen, {self.gen, self.param, fn}, self.state)
end

--------------------------------------------------------------------------------
-- Filtering
--------------------------------------------------------------------------------
local filter1_gen = function(fun, gen_x, param_x, state_x, a)
  while true do
    if state_x == nil or fun(a) then break; end
    state_x, a = gen_x(param_x, state_x)
  end
  return state_x, a
end

-- call each other
-- because we can't assign a vararg mutably in a while loop like filter1_gen
-- so we have to use recursion in calling both of these functions
local filterm_gen
local filterm_gen_shrink = function(fun, gen_x, param_x, state_x)
  return filterm_gen(fun, gen_x, param_x, gen_x(param_x, state_x))
end

filterm_gen = function(fun, gen_x, param_x, state_x, ...)
  if state_x == nil then
    return nil
  end

  if fun(...) then
    return state_x, ...
  end

  return filterm_gen_shrink(fun, gen_x, param_x, state_x)
end

local filter_detect = function(fun, gen_x, param_x, state_x, ...)
  if select('#', ...) < 2 then
    return filter1_gen(fun, gen_x, param_x, state_x, ...)
  else
    return filterm_gen(fun, gen_x, param_x, state_x, ...)
  end
end

local filter_gen = function(param, state_x)
    local gen_x, param_x, fun = param[1], param[2], param[3]
    return filter_detect(fun, gen_x, param_x, gen_x(param_x, state_x))
end

function Iterator:filter(fn)
  return wrap(filter_gen, {self.gen, self.param, fn}, self.state)
end

--------------------------------------------------------------------------------
-- Reducing
--------------------------------------------------------------------------------
function Iterator:any(fn)
  local r
  local state, param, gen = self.state, self.param, self.gen
  repeat
    state, r = call_if_not_empty(fn, gen(param, state))
  until state == nil or r
  return r
end

function Iterator:all(fn)
  local r
  local state, param, gen = self.state, self.param, self.gen
  repeat
    state, r = call_if_not_empty(fn, gen(param, state))
  until state == nil or not r
  return state == nil
end

function Iterator:find(val_or_fn)
  local gen, param, state = self.gen, self.param, self.state
  if type(val_or_fn) == "function" then
    return return_if_not_empty(filter_detect(val_or_fn, gen, param, gen(param, state)))
  else
    for _, r in gen, param, state do
      if r == val_or_fn then
        return r
      end
    end
    return nil
  end
end

function Iterator:tolist()
  local list = {}
  self:for_each(function(a)
    table.insert(list, a)
  end)
  return list
end

function Iterator:tolistn()
  local list = {}
  self:for_each(function(...)
    table.insert(list, {...})
  end)
  return list
end

function Iterator:tomap()
  local map = {}
  self:for_each(function(key, value)
    map[key] = value
  end)
  return map
end

--------------------------------------------------------------------------------
-- Compositions
--------------------------------------------------------------------------------
-- call each other
local chain_gen_r1
local chain_gen_r2 = function(param, state, state_x, ...)
  if state_x == nil then
    local i = state[1] + 1
    if param[3 * i - 1] == nil then
      return nil
    end
    state_x = param[3 * i]
    return chain_gen_r1(param, {i, state_x})
  end
  return {state[1], state_x}, ...
end

chain_gen_r1 = function(param, state)
  local i, state_x = state[1], state[2]
  local gen_x, param_x = param[3 * i - 2], param[3 * i - 1]
  return chain_gen_r2(param, state, gen_x(param_x, state_x))
end

local chain = function(...)
  local n = numargs(...)

  if n == 0 then
    return wrap(nil_gen, nil, nil)
  end

  local param = { [3 * n] = 0 }

  local i, gen_x, param_x, state_x
  for i = 1, n, 1 do
    local elem = select(i, ...)
    gen_x, param_x, state_x = unwrap(elem)
    param[3 * i - 2] = gen_x
    param[3 * i - 1] = param_x
    param[3 * i] = state_x
  end

  return wrap(chain_gen_r1, param, {1, param[3]})
end

Iterator.chain = chain
Iterator.__concat = chain
exports.chain = chain

--------------------------------------------------------------------------------
-- Operators
--------------------------------------------------------------------------------
exports.operator = {
    ----------------------------------------------------------------------------
    -- Comparison operators
    ----------------------------------------------------------------------------
    lt  = function(a, b) return a < b end,
    le  = function(a, b) return a <= b end,
    eq  = function(a, b) return a == b end,
    ne  = function(a, b) return a ~= b end,
    ge  = function(a, b) return a >= b end,
    gt  = function(a, b) return a > b end,

    ----------------------------------------------------------------------------
    -- Arithmetic operators
    ----------------------------------------------------------------------------
    add = function(a, b) return a + b end,
    div = function(a, b) return a / b end,
    floordiv = function(a, b) return math.floor(a/b) end,
    intdiv = function(a, b)
        local q = a / b
        if a >= 0 then return math.floor(q) else return math.ceil(q) end
    end,
    mod = function(a, b) return a % b end,
    mul = function(a, b) return a * b end,
    neq = function(a) return -a end,
    unm = function(a) return -a end, -- an alias
    pow = function(a, b) return a ^ b end,
    sub = function(a, b) return a - b end,
    truediv = function(a, b) return a / b end,

    ----------------------------------------------------------------------------
    -- String operators
    ----------------------------------------------------------------------------
    concat = function(a, b) return a..b end,
    len = function(a) return #a end,
    length = function(a) return #a end, -- an alias

    ----------------------------------------------------------------------------
    -- Logical operators
    ----------------------------------------------------------------------------
    land = function(a, b) return a and b end,
    lor = function(a, b) return a or b end,
    lnot = function(a) return not a end,
    truth = function(a) return not not a end,
}

return exports
