require('plenary.async_lib').tests.add_to_env()
local Semaphore = a.util.Semaphore

local eq = assert.are.same

a.describe('semaphore', function()
  a.it('should validate arguments', function()
    local status = pcall(Semaphore.new, -1)
    eq(status, false)

    local status = pcall(Semaphore.new)
    eq(status, false)
  end)

  a.it('should acquire a permit if available', function ()
    local sem = a.util.Semaphore.new(1)
    local permit = await(sem:acquire())
    assert(permit ~= nil)
  end)

  a.it('should block if no permit is available', function ()
    local sem = a.util.Semaphore.new(1)
    await(sem:acquire())
    
    local completed = false
    local blocking = async(function ()
      await(sem:acquire())
      completed = true
    end)
    a.run(blocking())

    eq(completed, false)
  end)

  a.it('should give another permit when an acquired permit is released', function ()
    local sem = a.util.Semaphore.new(1)
    local permit = await(sem:acquire())
    permit:forget()
    local next_permit = await(sem:acquire())
    assert(next_permit ~= nil)
  end)

  a.it('should permit the next waiting client when a permit is released', function () 
    local sem = a.util.Semaphore.new(1)
    local permit = await(sem:acquire())

    local completed = false
    local blocking = async(function ()
      await(sem:acquire())
      completed = true
    end)

    a.run(blocking())
    permit:forget()

    eq(completed, true)
  end)
end)
