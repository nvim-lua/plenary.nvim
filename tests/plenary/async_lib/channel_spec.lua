local a = require('plenary.async_lib')
local async = a.async
local await = a.await
local channel = a.util.channel
local runned = a.util.runned
local protected = a.util.protected

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('oneshot channel', function()
end)

describe('channel', function()
  describe('oneshot', function()
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

    it('should be able to protect a oneshot channel that was called twice', function ()
      local main = async(function()
        local tx, rx = channel.oneshot()
        tx(true)
        await(rx())
        local stat, ret = await(protected(rx()))
        eq(stat, false)
        assert(ret:match('Oneshot channel can only receive one value!'))
      end)

      a.block_on(main())
    end)
  end)
end)
