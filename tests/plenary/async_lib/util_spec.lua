require('plenary.async_lib').tests.add_to_env()
local block_on = a.util.block_on
local eq = assert.are.same
local id = a.util.id

a.describe('async await util', function()
  a.describe('block_on', function()
    a.it('should block_on', function()
      local fn = async(function()
        await(a.util.sleep(100))
        return 'hello'
      end)

      local res = block_on(fn())
      eq(res, 'hello')
    end)

    a.it('should work even when failing', function ()
      local nonleaf = async(function()
        eq(true, false)
      end)

      local stat = pcall(block_on, nonleaf())
      eq(stat, false)
    end)
  end)

  a.describe('protect', function()
    a.it('should be able to protect a non-leaf future', function()
      local nonleaf = async(function()
        error("This should error")
        return 'return'
      end)

      local stat, ret = await(a.util.protected_non_leaf(nonleaf()))
      eq(false, stat)
      assert(ret:match("This should error"))
    end)

    a.it('should be able to protect a non-leaf future that doesnt fail', function()
      local nonleaf = async(function()
        return 'didnt fail'
      end)

      local stat, ret = await(a.util.protected_non_leaf(nonleaf()))
      eq(stat, true)
      eq(ret, 'didnt fail')
    end)

    a.it('should be able to protect a leaf future', function()
      local leaf = a.wrap(function(callback)
        error("This should error")
        callback()
      end, 1)

      local stat, ret = await(a.util.protected(leaf()))
      eq(stat, false)
      assert(ret:match("This should error") ~= nil)
    end)

    a.it('should be able to protect a leaf future that doesnt fail', function()
      local fn = a.wrap(function(callback)
        callback('didnt fail')
      end, 1)

      local stat, ret = await(a.util.protected(fn()))
      eq(stat, true)
      eq(ret, 'didnt fail')
    end)
  end)

  a.describe('timeout', function()
    a.it('should block one and work', function()
      local timed_out = await(a.util.timeout(a.util.sleep(1000), 500))

      print('timed out 2:', timed_out)

      assert(timed_out == true)
    end)

    a.it('should work when timeout is longer', function ()
      local timed_out = await(a.util.timeout(a.util.sleep(100), 1000))

      print('timed out 1:', timed_out)

      assert(timed_out == false)
    end)
  end)

  a.it('id should work', function()
    eq(await(id(1, 2, 3, 4, 5)), 1, 2, 3, 4, 5)
  end)

  a.it('yield_now should work', function ()
    local yield_now = a.util.yield_now
    yield_now()
    yield_now()
    yield_now()
    yield_now()
    yield_now()
    yield_now()
    yield_now()
  end)
end)
