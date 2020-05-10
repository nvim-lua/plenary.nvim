

TestWaitTwo = {}

function TestWaitTwo:testSlow()
  local sum = 0
  for i = 1, 1000000 do
    sum = sum + 1
  end
end

return TestWaitTwo
