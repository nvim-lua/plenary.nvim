local a = require('plenary.async_lib')
local async = a.async
local await = a.await
local channel = a.utils.channel

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('oneshot channel', function()
  it('should work when rx is used first', a.convert(async(function()
    local rx, tx = channel.oneshot()

    a.run(future)
  end)))
end)
