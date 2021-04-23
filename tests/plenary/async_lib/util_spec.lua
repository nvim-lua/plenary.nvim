require('plenary.async_lib').tests.add_to_env()
local block_on = a.util.block_on
local eq = assert.are.same
local id = a.util.id

a.describe('async await util', function()
  a.describe('block_on', function()
    a.it('should block_on', function()
      local fn = function()
        a.util.sleep(100)
        return 'hello'
      end

      local res = fn()
      eq(res, 'hello')
    end)

    a.it('should work even when failing', function ()
      local nonleaf = function()
        eq(true, false)
      end

      local stat = pcall(block_on, nonleaf)
      eq(stat, false)
    end)
  end)

  a.describe('protect', function()
    a.it('should be able to protect a non-leaf future', function()
      local nonleaf = function()
        error("This should error")
        return 'return'
      end

      local stat, ret = pcall(nonleaf)
      eq(false, stat)
      assert(ret:match("This should error"))
    end)

    a.it('should be able to protect a non-leaf future that doesnt fail', function()
      local nonleaf = function()
        return 'didnt fail'
      end

      local stat, ret = pcall(nonleaf)
      eq(stat, true)
      eq(ret, 'didnt fail')
    end)
  end)

  a.describe('timeout', function()
    a.it('should block one and work', function()
      local timed_out = a.util.timeout(a.util.sleep(1000), 500)

      print('timed out 2:', timed_out)

      assert(timed_out == true)
    end)

    a.it('should work when timeout is longer', function ()
      local timed_out = a.util.timeout(a.util.sleep(100), 1000)

      print('timed out 1:', timed_out)

      assert(timed_out == false)
    end)
  end)
end)
