local a = require('plenary.async_lib')
local async = a.async
local await_all = a.await_all
local work = a.work

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('should await_all', function()
  it('simple', function()
    local fn = async(function()
      local futures = {}
      for i = 1, 100 do futures[i] = work.string.match('hello', 'llo') end

      local result = await_all(futures)

      local expected = {}
      for i = 1, 100 do expected[i] = {'llo'} end

      eq(result, expected)
    end)

    a.run(fn())
  end)
end)
