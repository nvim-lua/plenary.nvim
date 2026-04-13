---@brief [[
--- This module defines an idiomatic way to create enum classes, similar to
--- those in java or kotlin. There are two ways to create an enum, one is with
--- the exported `make_enum` function, or calling the module directly with the
--- enum spec.
---
--- The enum spec consists of a list-like table whose members can be either a
--- string or a tuple of the form {string, number}. In the former case, the enum
--- member will take the next available value, while in the latter, the member
--- will take the string as it's name and the number as it's value. In both
--- cases, the name must start with a capital letter.
---
--- Here is an example:
---
--- <pre>
--- local Enum = require 'plenary.enum'
--- local myEnum = Enum {
---     'Foo',          -- Takes value 1
---     'Bar',          -- Takes value 2
---     {'Qux', 10},    -- Takes value 10
---     'Baz',          -- Takes value 11
--- }
--- </pre>
---
--- In case of name or value clashing, the call will fail. For this reason, it's
--- best if you define the members in ascending order.
---@brief ]]
---@class PlenaryEnum
---@field is_enum fun(tbl: table): boolean
---@field make_enum fun(tbl: PlenaryEnumRawTable): PlenaryEnumEnum
---@overload fun(tbl: PlenaryEnumRawTable): PlenaryEnumEnum

---@alias PlenaryEnumRawTable (string|{ [1]: string, [2]: integer })[]

---@class PlenaryEnumEnum
---@field [integer] string
---@field [string] PlenaryVariant
local Enum = {}

---@param name string
---@return string
local function validate_member_name(name)
  if #name > 0 and name:sub(1, 1):match "%u" then
    return name
  end
  error('"' .. name .. '" should start with a capital letter')
end

--- Creates an enum from the given list-like table, like so:
--- <pre>
--- local enum = Enum.make_enum{
---     'Foo',
---     'Bar',
---     {'Qux', 10}
--- }
--- </pre>
---@param tbl PlenaryEnumRawTable
---@return PlenaryEnumEnum: A new enum
local function make_enum(tbl)
  ---@type PlenaryEnumEnum
  local enum = {}

  ---@class PlenaryVariant
  ---@field value integer
  local Variant = {}
  Variant.__index = Variant

  ---@param i integer
  ---@return PlenaryVariant
  local function newVariant(i)
    return setmetatable({ value = i }, Variant)
  end

  -- we don't need __eq because the __eq metamethod will only ever be
  -- invoked when they both have the same metatable

  ---@param o PlenaryVariant
  ---@return boolean
  function Variant:__lt(o)
    return self.value < o.value
  end

  ---@param o PlenaryVariant
  ---@return boolean
  function Variant:__gt(o)
    return self.value > o.value
  end

  ---@return string
  function Variant:__tostring()
    return tostring(self.value)
  end

  ---@param e PlenaryEnumEnum
  ---@param i integer
  ---@return integer
  local function find_next_idx(e, i)
    local newI = i + 1
    if not e[newI] then
      return newI
    end
    error("Overlapping index: " .. tostring(newI))
  end

  local i = 0

  for _, v in ipairs(tbl) do
    if type(v) == "string" then
      local name = validate_member_name(v)
      local idx = find_next_idx(enum, i)
      enum[idx] = name
      if enum[name] then
        error("Duplicate enum member name: " .. name)
      end
      enum[name] = newVariant(idx)
      i = idx
    elseif type(v) == "table" and type(v[1]) == "string" and type(v[2]) == "number" then
      local name = validate_member_name(v[1])
      local idx = v[2]
      if enum[idx] then
        error("Overlapping index: " .. tostring(idx))
      end
      enum[idx] = name
      if enum[name] then
        error("Duplicate name: " .. name)
      end
      enum[name] = newVariant(idx)
      i = idx
    else
      error "Invalid way to specify an enum variant"
    end
  end

  return require("plenary.tbl").freeze(setmetatable(enum, Enum))
end

---@param _ PlenaryEnumEnum
---@param key string|integer
---@return string|PlenaryVariant
Enum.__index = function(_, key)
  if Enum[key] then
    return Enum[key]
  end
  error("Invalid enum key: " .. tostring(key))
end

--- Checks whether the enum has a member with the given name
---@param key string The element to check for
---@return boolean has_key True if key is present
function Enum:has_key(key)
  if rawget(getmetatable(self).__index, key) then
    return true
  end
  return false
end

--- If there is a member named 'key', return it, otherwise return nil
---@param key string The element to check for
---@return PlenaryVariant? variant The element named by key, or nil if not present
function Enum:from_str(key)
  if self:has_key(key) then
    return self[key]
  end
end

--- If there is a member of value 'num', return it, otherwise return nil
--- @param num integer The value of the element to check for
--- @return PlenaryVariant? variant The element whose value is num
function Enum:from_num(num)
  local key = self[num]
  if key then
    return self[key]
  end
end

--- Checks whether the given object corresponds to an instance of Enum
---@param tbl table The object to be checked
---@return boolean is_enum True if tbl is an Enum
local function is_enum(tbl)
  return getmetatable(getmetatable(tbl).__index) == Enum
end

return setmetatable({ is_enum = is_enum, make_enum = make_enum }, {
  __call = function(_, tbl)
    return make_enum(tbl)
  end,
}) --[[@as PlenaryEnum]]
