local tbl = require('plenary/tbl')

local rotate = require('plenary/vararg').rotate

local function rotate_n(first, ...)
  local args = tbl.pack(...)
  args[#args+1] = first
  return tbl.unpack(args)
end

local num = 2e7 -- 2e4

local t1 = os.clock()
for i = 1, num do
  local a, b, c, d, e, f, g = rotate(1, 2, 3, 4, 5, 6)
end
local t2 = os.clock()
print('rotate:  ', t2 - t1)

local t1 = os.clock()
for i = 1, num do
  local a, b, c, d, e, f, g = rotate_n(1, 2, 3, 4, 5, 6)
end
local t2 = os.clock()

print('rotate_n: ', t2 - t1)
