local parsec = require'plenary.parsec'

-- dump(parsec)

-- dump(parsec.letter("hello____"))
-- dump(parsec.satisfy(function() end))
local letter = parsec.satisfy(parsec.is_letter)
-- dump(letter)
dump(letter("hello____"))
-- dump(parsec.satisfy)
-- local i, o = parsec.letter("hello____")
-- dump(i, o)
-- print(parsec.Parser(function() end))
