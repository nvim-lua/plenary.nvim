
TestWaitOne = {}

function TestWaitOne:testSlow()
  local sum = 0
  for i = 1, 1000000000 do
    sum = sum + 1
  end
end

return TestWaitOne
