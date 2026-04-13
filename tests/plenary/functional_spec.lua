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

    describe("all", function()
      it("returns true when all elements satisfy predicate", function()
        assert.is_true(f.all(function(_, x) return x < 10 end, {1, 2, 3, 4}))
      end)

      it("returns false if any element fails predicate", function()
        assert.is_false(f.all(function(_, x) return x < 10 end, {1, 2, 30, 4}))
      end)

      it("returns true on empty list", function()
        assert.is_true(f.all(function(_, x) return false end, {}))
      end)
    end)

    describe("any", function()
      it("returns true if any element satisfies predicate", function()
        assert.is_true(f.any(function(_, v) return v > 10 end, {1, 2, 12, 4}))
      end)

      it("returns false when no elements match", function()
        assert.is_false(f.any(function(_, v) return v > 10 end, {1, 2, 3, 4}))
      end)

      it("returns false on empty list", function()
        assert.is_false(f.any(function(_, v) return true end, {}))
      end)
    end)

    describe("if_nil", function()
      it("returns was_nil value if nil", function()
        assert.equals("fallback", f.if_nil(nil, "fallback", "not nil"))
      end)

      it("returns was_not_nil value if not nil", function()
        assert.equals("not nil", f.if_nil(5, "fallback", "not nil"))
      end)
    end)
  end)


