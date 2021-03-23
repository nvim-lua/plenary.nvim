require('plenary.async_lib').tests.add_to_env()
local channel = a.util.channel
local eq = assert.are.same

a.describe('oneshot channel', function()
  a.it('should work when rx is used first', function()
    local tx, rx = channel.oneshot()

    a.run(a.future(function()
      local got = await(rx())
      eq("sent value", got)
    end))

    tx("sent value")
  end)

  a.it('should work when tx is used first', function()
    local tx, rx = channel.oneshot()

    tx("sent value")

    a.run(a.future(function()
      local got = await(rx())
      eq("sent value", got)
    end))
  end)

  a.it('should work with multiple returns', function()
    local tx, rx = channel.oneshot()

    a.run(a.future(function()
      local got, got2 = await(rx())
      eq("sent value", got)
      eq("another sent value", got2)
    end))

    tx("sent value", "another sent value")
  end)
end)
