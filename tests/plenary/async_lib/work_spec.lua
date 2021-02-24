local a = require('plenary.async_lib')
local async = a.async
local await = a.await
local work = a.work

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('work', function()
  it('should wrap functions', function()
    local future = async(function()
      local actual = await(work.string.match("abcdefg", 'b..'))
      eq(actual, 'bcd')
    end)

    a.run(future)
  end)
end)
