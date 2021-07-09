local iter_lines = require('plenary.iterators').lines

local text = [[
hello
world
this
is
me
]]

-- for v in string.gmatch(text, "([^\n]*)\n") do
--   print(v)
-- end

-- print(iter_lines(text))

local matcher = iter_lines(text)

local result = { matcher() }
P(result)

result = { matcher(matcher.param, result[1]) }
P(result)

result = { matcher(matcher.param, result[1]) }
P(result)
-- print(matcher())

-- local state, val = nil, nil
-- gen, val, state = matcher(text, nil)

-- print(gen, val, state)

-- state, val = matcher(state)
-- print(val)

-- print(matcher)
-- print(matcher)
-- print(matcher)
-- print(matcher())
