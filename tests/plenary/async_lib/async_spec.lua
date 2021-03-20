local a = require('plenary.async_lib')
local async, await = a.async, a.await
local await_all = a.await_all
local work = a.work

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('async await', function()
  it('should await_all', function()
    local fn = async(function()
      local futures = {}
      for i = 1, 100 do futures[i] = work.string.match('hello', 'llo') end

      local result = await_all(futures)

      local expected = {}
      for i = 1, 100 do expected[i] = {'llo'} end

      eq(result, expected)
    end)

    a.run(fn())
  end)

  it('should block_on', function()
    local fn = async(function()
      await(a.utils.sleep(100))
      return 'hello'
    end)

    local res = a.block_on(fn())
    eq(res, 'hello')
  end)

  describe('protect', function()
    it('should be able to protect a non-leaf future', function()
      local fn = async(function()
        error("This should error")
      end)

      local main = async(function()
        local stat, ret = await(a.utils.protected(fn()))
        eq(stat, false)
        assert(ret:match("This should error") ~= nil)
      end)

      a.run(main())
    end)

    it('should be able to protect a leaf future', function()
      local fn = a.wrap(function(callback)
        error("This should error")
        callback()
      end, 1)

      local main = async(function()
        local stat, ret = await(a.utils.protected(fn()))
        eq(stat, false)
        assert(ret:match("This should error") ~= nil)
      end)

      a.run(main())
    end)

    it('should be able to protect a leaf future that doesnt fail', function()
      local fn = a.wrap(function(callback)
        callback('didnt fail')
      end, 1)

      local main = async(function()
        local stat, ret = await(a.utils.protected(fn()))
        eq(stat, true)
        eq(ret, 'didnt fail')
      end)

      a.run(main())
    end)

    it('should be able to protect a non-leaf future that doesnt fail', function()
      local fn = async(function()
        return 'didnt fail'
      end)

      local main = async(function()
        local stat, ret = await(a.utils.protected(fn()))
        eq(stat, true)
        eq(ret, 'didnt fail')
      end)

      a.run(main())
    end)
  end)
end)
