require('plenary.async_lib').tests.add_to_env()
local channel = a.util.channel
local eq = assert.are.same
local protected = a.util.protected

a.describe('channel', function()
  a.describe('oneshot', function()
    a.it('should work when rx is used first', function()
      local tx, rx = channel.oneshot()

      a.run(function()
        local got = rx()

        eq("sent value", got)
      end)

      tx("sent value")

    end)

    a.it('should work when tx is used first', function()
      local tx, rx = channel.oneshot()

      tx("sent value")

      local got = rx()

      eq("sent value", got)
    end)

    a.it('should work with multiple returns', function()
      local tx, rx = channel.oneshot()

      a.run(function()
        local got, got2 = await(rx())
        eq("sent value", got)
        eq("another sent value", got2)
      end)

      tx("sent value", "another sent value")
    end)

    a.it('should work when sending a nil value', function ()
      local tx, rx = channel.oneshot()

      tx(nil)

      local res = await(rx())
      eq(res, nil)

      local stat, ret = protected(rx)()
      eq(stat, false)
      local stat, ret = protected(rx)()
      eq(stat, false)
    end)

    a.it('should block sending mulitple times', function()
      local tx, rx = channel.oneshot()

      tx()
      local stat = pcall(tx)
      eq(stat, false)
    end)

    a.it('should block receiving multiple times', function()
      local tx, rx = channel.oneshot()
      tx()
      rx()
      local stat = protected(rx)()
      eq(stat, false)
    end)
  end)

  a.describe('counter', function()
    a.it('should work', function()
      local tx, rx = channel.counter()

      tx.send()
      tx.send()
      tx.send()

      local counter = 0

      a.run(function()
        for i = 1, 3 do
          rx.recv()
          counter = counter + 1
        end
      end)

      eq(counter, 3)
    end)

    a.it('should work when getting last', function()
      local tx, rx = channel.counter()

      tx.send()
      tx.send()
      tx.send()

      local counter = 0

      a.run(function()
        await(rx.last())
        counter = counter + 1
      end)

      eq(counter, 1)
    end)
  end)
end)
