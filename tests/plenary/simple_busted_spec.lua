local eq = assert.are.same

local tester_function = function()
  error(7)
end

describe("busted specs", function()
  describe("nested", function()
    it("should work", function()
      assert(true)
    end)
  end)

  it("should not nest", function()
    assert(true)
  end)

  it("should not fail unless we unpcall this", function()
    pcall(tester_function)
  end)

  pending("other thing pending", function()
    error()
  end)
end)

describe("before each", function()
  local a = 2
  local b = 3
  it("is not cleared", function()
    eq(2, a)
    eq(3, b)
    a = a + 1
    b = b + 1
  end)
  describe("nested", function()
    before_each(function()
      a = 0
    end)
    it("should clear a but not b", function()
      eq(0, a)
      eq(4, b)
      a = a + 1
      b = b + 1
    end)
    describe("nested nested", function()
      before_each(function()
        b = 0
      end)
      it("should clear b as well", function()
        eq(0, a)
        eq(0, b)
        a = a + 1
        b = b + 1
      end)
    end)
    it("should only clear a", function()
      eq(0, a)
      eq(1, b)
      a = a + 1
      b = b + 1
    end)
  end)
  it("should clear nothing", function()
    eq(1, a)
    eq(2, b)
  end)
end)

describe("before_each ordering", function()
  local order = ""
  before_each(function()
    order = order .. "1,"
  end)
  before_each(function()
    order = order .. "2,"
  end)
  describe("nested 1 deep", function()
    before_each(function()
      order = order .. "3,"
    end)
    before_each(function()
      order = order .. "4,"
    end)
    describe("nested 2 deep", function()
      before_each(function()
        order = order .. "5,"
      end)
      it("runs before_each`s in order", function()
        eq("1,2,3,4,5,", order)
      end)
    end)
  end)
  describe("adjacent nested 1 deep", function()
    before_each(function()
      order = order .. "3a,"
    end)
    before_each(function()
      order = order .. "4a,"
    end)
    describe("nested 2 deep", function()
      before_each(function()
        order = order .. "5a,"
      end)
      it("runs before_each`s in order", function()
        eq("1,2,3,4,5,1,2,3a,4a,5a,", order)
      end)
    end)
  end)
end)

describe("after each", function()
  local a = 2
  local b = 3
  it("is not cleared", function()
    eq(2, a)
    eq(3, b)
    a = a + 1
    b = b + 1
  end)
  describe("nested", function()
    after_each(function()
      a = 0
    end)
    it("should not clear any at this point", function()
      eq(3, a)
      eq(4, b)
      a = a + 1
      b = b + 1
    end)
    describe("nested nested", function()
      after_each(function()
        b = 0
      end)
      it("should have cleared a", function()
        eq(0, a)
        eq(5, b)
        a = a + 1
        b = b + 1
      end)
    end)
    it("should have cleared a and b", function()
      eq(0, a)
      eq(0, b)
      a = a + 1
      b = b + 1
    end)
  end)
  it("should only have cleared a", function()
    eq(0, a)
    eq(1, b)
  end)
end)

describe("after_each ordering", function()
  local order = ""
  describe("1st describe having after_each", function()
    after_each(function()
      order = order .. "1,"
    end)
    after_each(function()
      order = order .. "2,"
    end)
    describe("nested 1 deep", function()
      after_each(function()
        order = order .. "3,"
      end)
      after_each(function()
        order = order .. "4,"
      end)
      describe("nested 2 deep", function()
        after_each(function()
          order = order .. "5,"
        end)
        it("a test to trigger the after_each`s", function()
          assert(true)
        end)
      end)
    end)
    describe("adjacent nested 1 deep", function()
      after_each(function()
        order = order .. "3a,"
      end)
      after_each(function()
        order = order .. "4a,"
      end)
      describe("nested 2 deep", function()
        after_each(function()
          order = order .. "5a,"
        end)
        it("a test to trigger the adjacent after_each`s", function()
          assert(true)
        end)
      end)
    end)
  end)
  it("ran after_each`s in order", function()
    eq("1,2,3,4,5,1,2,3a,4a,5a,", order)
  end)
end)

describe("another top level describe test", function()
  it("should work", function()
    eq(1, 1)
  end)
end)
