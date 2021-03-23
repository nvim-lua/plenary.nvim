local a = require('plenary.async_lib')
local await = a.await
local describe, it = a.tests.describe, a.tests.it

describe('tests', function ()
  it('should block one and work', function ()
    local timed_out = await(a.util.timeout(a.util.sleep(1000), 500))

    print('timed out 2:', timed_out)

    assert(timed_out == true)
  end)
end)
