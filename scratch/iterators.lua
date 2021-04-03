local i = require('plenary.iterators')

-- local iter, param, state = i.iter { 1, i.iter { 2, 3 } }
-- dump("starting iterator", iter)

-- state, it = iter.gen(param, state)
-- dump(state, it)

-- state, it = iter.gen(param, state)
-- dump(state, it)

-- local tail = i.wrap(iter.gen, param, state)

-- local new_iter = it:chain(tail)

-- state, it = new_iter.gen(new_iter.param, new_iter.state)
-- dump(state, it)

-- state, it = new_iter.gen(new_iter.param, state)
-- dump(state, it)

-- state, it = new_iter.gen(new_iter.param, state)
-- dump(state, it)

-- state, it = new_iter.gen(new_iter.param, state)
-- dump(state, it)
-- local iter, param, state = i.iter { 2, 3 }:chain(i.iter { 1 })

-- local iter, param, state = i.chain(i.iter { 2, 3 }, i.iter { 1 })

-- state, it = iter.gen(param, state)
-- dump(state, it)

-- state, it = iter.gen(param, state)
-- dump(state, it)

-- state, it = iter.gen(param, state)
-- dump(state, it)

-- state, it = iter.gen(param, state)
-- dump(state, it)

local first_iter = i.iter { 2, 3 }
-- dump(first_iter)

local iter, param, state = i.iter { 1, first_iter }
-- dump(iter)
state = 0
state, it = iter.gen(param, state)
dump(state, it)
