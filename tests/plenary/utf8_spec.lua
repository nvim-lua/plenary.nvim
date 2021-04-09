local utf8 = require('plenary.utf8')
local i = require('plenary.iterators')
local eq = assert.are.same

describe('utf8', function()
  describe('code point iterator', function()
    it('should iterator over regular ascii', function()
      eq(utf8.chars("hello"):tolist(), i.bytes("hello"):tolist())
    end)

    it('should iterate', function()
      eq(utf8.chars("Привет"):tolist(), {"П", "р", "и", "в", "е", "т"})
      assert(i.bytes("Привет") ~= {"П", "р", "и", "в", "е", "т"})
    end)

    it('should iterator over emojis', function()
      eq(utf8.chars("💖"):tolist(), {"💖"})

      assert(i.bytes("💖"):tolist() ~= {"💖"})
    end)
  end)

  describe('char bytes', function()
  end)
end)
