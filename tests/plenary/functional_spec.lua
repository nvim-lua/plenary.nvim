local f = require "plenary.functional"

describe("functional", function()
  describe("partial", function()
    local function args(...)
      assert.is.equal(4, select("#", ...))
      return table.concat({ ... }, ",")
    end
    it("should bind correct parameters", function()
      local expected = args(1, 2, 3, 4)
      assert.is.equal(expected, f.partial(args)(1, 2, 3, 4))
      assert.is.equal(expected, f.partial(args, 1)(2, 3, 4))
      assert.is.equal(expected, f.partial(args, 1, 2)(3, 4))
      assert.is.equal(expected, f.partial(args, 1, 2, 3)(4))
      assert.is.equal(expected, f.partial(args, 1, 2, 3, 4)())
    end)
  end)
end)
