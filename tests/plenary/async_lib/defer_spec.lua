require('plenary.async_lib').tests.add_to_env()

-- a.describe('defer', function()
--   a.it('should run at the end', function()
--     local counter = 0

--     local should_defer = async(function()
--       counter = counter + 1
--     end)

--   end)
-- end)
local final_wrap = a.wrap(function(cb) cb() end, 1)

local final = async(function()
  await(final_wrap())
end)

local another_async_func = async(function()
  await(final())
  a.defer(final(), 1)
end)

local async_func = async(function()
  await(another_async_func())
  a.defer(another_async_func())
  a.defer(final())
end)

a.run(async_func())
