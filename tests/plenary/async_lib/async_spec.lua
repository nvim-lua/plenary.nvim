local a = require('plenary.async_lib')
local async, await = a.async, a.await
local await_all = a.await_all
local block_on = a.util.block_on

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('async await', function()
  it('should block_on', function()
    local fn = async(function()
      await(a.util.sleep(100))
      return 'hello'
    end)

    local res = block_on(fn())
    eq(res, 'hello')
  end)

  describe('protect', function()
    it('should be able to protect a non-leaf future', function()
      local fn = async(function()
        error("This should error")
        return 'return'
      end)

      local main = async(function()
        local stat, ret = await(a.util.protected_non_leaf(fn()))
        eq(false, stat)
        assert(ret:match("This should error"))
        return 'hello'
      end)

      local res = block_on(main())
      eq(res, 'hello')
    end)

    it('should be able to protect a non-leaf future that doesnt fail', function()
      local fn = async(function()
        return 'didnt fail'
      end)

      local main = async(function()
        local stat, ret = await(a.util.protected_non_leaf(fn()))
        eq(stat, true)
        eq(ret, 'didnt fail')
      end)

      block_on(main())
    end)

    it('should be able to protect a leaf future', function()
      local fn = a.wrap(function(callback)
        error("This should error")
        callback()
      end, 1)

      local main = async(function()
        local stat, ret = await(a.util.protected(fn()))
        eq(stat, false)
        assert(ret:match("This should error") ~= nil)
      end)

      block_on(main())
    end)

    it('should be able to protect a leaf future that doesnt fail', function()
      local fn = a.wrap(function(callback)
        callback('didnt fail')
      end, 1)

      local main = async(function()
        local stat, ret = await(a.util.protected(fn()))
        eq(stat, true)
        eq(ret, 'didnt fail')
      end)

      block_on(main())
    end)
  end)
end)
