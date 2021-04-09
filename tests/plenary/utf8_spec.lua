local utf8 = require('plenary.utf8')
local i = require('plenary.iterators')
local eq = assert.are.same

describe('utf8', function()
  describe('code point iterator', function()
    it('should iterator over regular ascii', function()
      eq(utf8.chars("hello"):tolist(), {"h", "e", "l", "l", "o"})
    end)

    it('should iterate', function()
      eq(utf8.chars("Привет"):tolist(), {"П", "р", "и", "в", "е", "т"})
      assert(i.iter("Привет") ~= {"П", "р", "и", "в", "е", "т"})
    end)

    it('should iterator over emojis', function()
      eq(utf8.chars("💖"):tolist(), {"💖"})

      assert(i.iter("💖"):tolist() ~= {"💖"})
    end)
  end)
end)
