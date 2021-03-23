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

  a.it('should count properly', function()
  end)
end)
