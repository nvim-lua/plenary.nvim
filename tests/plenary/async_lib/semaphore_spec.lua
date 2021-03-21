local a = require('plenary.async_lib')
local async = a.async
local await = a.await
local Semaphore = a.util.Semaphore

local eq = assert.are.same

describe('semaphore', function()
  it('should validate arguments', function()
    local status = pcall(Semaphore.new, -1)
    eq(status, false)

    local status = pcall(Semaphore.new)
    eq(status, false)
  end)

  it('should count properly', function()
  end)
end)
