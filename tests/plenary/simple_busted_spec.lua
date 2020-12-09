local tester_function = function()
  error(7)
end

describe('busted specs', function()
  describe('nested', function()
    it('should work', function()
      assert(true)
    end)
  end)

  it('should not nest', function()
    assert(true)
  end)

  it('should not fail unless we unpcall this', function()
    pcall(tester_function)
  end)

  pending("Other thing", function()
    error()
  end)
end)
