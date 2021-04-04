local i = require('plenary.iterators')

local iter = i.range(3):stateful()
-- dump(iter:tolist())
dump(iter:tolist())
