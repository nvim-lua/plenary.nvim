local parsec = require'plenary.parsec'
local eq = assert.are.same

describe('parsec', function()
  it('should see if letter', function()
    eq(parsec.is_letter('h'), true)
  end)

  describe('safisfy', function()
    it('should satisfy letter', function()
      local i, o = parsec.letter("hello____")
      -- eq(i, "____")
      -- eq(o, "hello")
    end)

    -- it('should error when not consume', function()
      -- why does this not work
      -- local stat, i, o = pcall(parsec.letter, "_________")
      -- parsec.letter("___________")
      -- eq(stat, false)
    -- end)
  end)
end)
