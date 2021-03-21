local a = require('plenary.async_lib')
local async = a.async
local await_all = a.await_all
local await = a.await
local Condvar = a.util.Condvar

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('condvar', function()
  it('should allow blocking', function()
    local var = false

    local condvar = Condvar.new()

    local blocking = async(function()
      await(condvar:wait())
      var = true
    end)

    a.run(blocking())

    eq(var, false)

    condvar:notify_one()

    eq(var, true)
  end)

  it('should be able to notify one when running', function()
    local counter = 0

    local condvar = Condvar.new()

    local first = async(function()
      await(condvar:wait())
      counter = counter + 1
    end)

    local second = async(function()
      await(condvar:wait())
      counter = counter + 1
    end)

    local third = async(function()
      await(condvar:wait())
      counter = counter + 1
    end)

    a.run_all { first(), second(), third() }

    eq(0, counter)

    condvar:notify_one()

    eq(1, counter)

    condvar:notify_one()

    eq(counter, 2)

    condvar:notify_one()

    eq(counter, 3)
  end)

  it('should allow notify_one to work when using await_all', function()
    local future = async(function()
      local counter = 0

      local condvar = Condvar.new()

      local first = async(function()
        await(condvar:wait())
        counter = counter + 1
      end)

      local second = async(function()
        await(condvar:wait())
        counter = counter + 1
      end)

      local third = async(function()
        await(condvar:wait())
        counter = counter + 1
      end)

      await_all { first(), second(), third() }

      eq(0, counter)

      condvar:notify_one()

      eq(1, counter)

      condvar:notify_one()

      eq(counter, 2)

      condvar:notify_one()

      eq(counter, 3)
    end)

    a.run(future())

    end)

  it('should notify_all', function()
    local counter = 0

    local condvar = Condvar.new()

    local first = async(function()
      await(condvar:wait())
      counter = counter + 1
    end)

    local second = async(function()
      await(condvar:wait())
      counter = counter + 1
    end)

    local third = async(function()
      await(condvar:wait())
      counter = counter + 1
    end)

    a.run_all { first(), second(), third() }

    eq(0, counter)

    condvar:notify_all()

    eq(3, counter)
  end)
end)
