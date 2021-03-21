local a = require('plenary.async_lib')
local async = a.async
local await = a.await
local channel = a.util.channel
local runned = a.util.runned

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('oneshot channel', function()
  it('should work when rx is used first', runned(a.future(function()
    local tx, rx = channel.oneshot()

    a.run(a.future(function()
      local got = await(rx())
      eq("sent value", got)
    end))

    tx("sent value")
  end)))

  it('should work when tx is used first', runned(a.future(function()
    local tx, rx = channel.oneshot()

    tx("sent value")

    a.run(a.future(function()
      local got = await(rx())
      eq("sent value", got)
    end))
  end)))

  it('should work with multiple returns', runned(a.future(function()
    local tx, rx = channel.oneshot()

    a.run(a.future(function()
      local got, got2 = await(rx())
      eq("sent value", got)
      eq("another sent value", got2)
    end))

    tx("sent value", "another sent value")
  end)))
end)
