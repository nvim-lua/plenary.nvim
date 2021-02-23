local a = require('plenary.async')
local Condvar = a.utils.Condvar

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('condvar', function()
  it('should allow blocking', function()
    local var = false

    local condvar = Condvar.new()

    local blocking = a.sync(function()
      a.wait(condvar:wait())
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

    local first = a.sync(function()
      a.wait(condvar:wait())
      counter = counter + 1
    end)

    local second = a.sync(function()
      a.wait(condvar:wait())
      counter = counter + 1
    end)

    local third = a.sync(function()
      a.wait(condvar:wait())
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
    local future = a.sync(function()
      local counter = 0

      local condvar = Condvar.new()

      local first = a.sync(function()
        a.wait(condvar:wait())
        counter = counter + 1
      end)

      local second = a.sync(function()
        a.wait(condvar:wait())
        counter = counter + 1
      end)

      local third = a.sync(function()
        a.wait(condvar:wait())
        counter = counter + 1
      end)

      a.wait_all { first(), second(), third() }

      eq(0, counter)

      condvar:notify_one()

      eq(1, counter)

      condvar:notify_one()

      eq(counter, 2)

      condvar:notify_one()

      eq(counter, 3)
    end)

    a.run(future)

    end)

  it('should notify_all', function()
    local counter = 0

    local condvar = Condvar.new()

    local first = a.sync(function()
      a.wait(condvar:wait())
      counter = counter + 1
    end)

    local second = a.sync(function()
      a.wait(condvar:wait())
      counter = counter + 1
    end)

    local third = a.sync(function()
      a.wait(condvar:wait())
      counter = counter + 1
    end)

    a.run_all { first(), second(), third() }

    eq(0, counter)

    condvar:notify_all()

    eq(3, counter)
  end)
end)
