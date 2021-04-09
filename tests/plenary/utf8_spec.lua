local utf8 = require('plenary.utf8')
local i = require('plenary.iterators')
local eq = function(a, b)
  assert(vim.deep_equal(a, b))
end
local not_eq = function(a, b)
  assert(not vim.deep_equal(a, b))
end

describe('utf8', function()
  describe('code point iterator', function()
    it('should iterator over regular ascii', function()
      eq(utf8.chars("hello"):tolist(), i.bytes("hello"):tolist())
    end)

    it('should iterate', function()
      eq(utf8.chars("Привет"):tolist(), {"П", "р", "и", "в", "е", "т"})
      not_eq(i.bytes("Привет") ~= {"П", "р", "и", "в", "е", "т"})
    end)

    it('should iterator over emojis', function()
      eq(utf8.chars("💖"):tolist(), {"💖"})

      assert(i.bytes("💖"):tolist() ~= {"💖"})
    end)
  end)

  describe('char bytes', function()
    it('should do correctly', function()
      local emoji = "💖"
      eq(utf8.charbytes(emoji), 4)

      local c = "П"
      eq(utf8.charbytes(c), 2)

      c = '®'
      eq(utf8.charbytes(c), 2)

      c = 'a'
      eq(utf8.charbytes(c), 1)

      c = '😊'
      eq(utf8.charbytes(c), 4)
    end)
  end)
end)
