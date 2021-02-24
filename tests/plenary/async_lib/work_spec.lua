local a = require('plenary.async_lib')
local async = a.async
local await = a.await
local work = a.work

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('work', function()
  it('should should wrap with callback', function()
    local wrapped = work.work_wrap(function(...) return string.format(...) end)
    wrapped('abcdefg', "b..", function(res)
      eq(res, 'bcd')
    end)
  end)

  it('should wrap functions', function()
    local fn = async(function()
      local actual = await(work.string.match("abcdefg", 'b..'))
      eq(actual, 'bcd')
    end)

    a.run(fn())
  end)
end)
