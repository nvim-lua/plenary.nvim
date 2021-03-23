require('plenary.async_lib').tests.add_to_env()
local channel = a.util.channel
local eq = assert.are.same
local protected = a.util.protected

a.describe('channel', function()
  a.describe('oneshot', function()
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

    a.it('should work when sending a nil value', function ()
      local tx, rx = channel.oneshot()

      tx(nil)

      local res = await(rx())
      eq(res, nil)

      local stat, ret = await(protected(rx()))
      eq(stat, false)
      local stat, ret = await(protected(rx()))
      eq(stat, false)
    end)

    a.it('should block sending mulitple times', function()
      local tx, rx = channel.oneshot()

      tx()
      local stat = pcall(tx)
      eq(stat, false)
    end)

    a.it('should block receiving multiple times', function ()
      local tx, rx = channel.oneshot()
      tx()
      await(rx())
      local stat = await(protected(rx()))
      eq(stat, false)
    end)
  end)
end)
