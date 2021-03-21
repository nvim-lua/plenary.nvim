local a = require('plenary.async_lib')
local async = a.async
local await = a.await

local main1 = async(function()
  local timed_out = await(a.util.timeout(a.util.sleep(100), 1000))

  print('timed out 1:', timed_out)

  assert(timed_out == false)
end)

local main2 = async(function()
  local timed_out = await(a.util.timeout(a.util.sleep(1000), 500))

  print('timed out 2:', timed_out)

  assert(timed_out == true)
end)

a.run_all { main1(), main2() }
