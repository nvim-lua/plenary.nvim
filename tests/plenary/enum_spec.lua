local Enum = require 'plenary.enum'

local function should_fail(fun)
  local stat = pcall(fun)
  assert(not stat, "Function should fail")
end

describe('Enum', function()
  it('should be able to define specific values for members', function()
    local E = Enum{
      {'Foo', 3},
      {'Bar', 2},
      'Qux',
      'Baz',
      {'Another', 11}
    }

    assert(E.Foo:id() == 3)
    assert(E.Bar:id() == 2)
    assert(E.Qux:id() == 4)
    assert(E.Baz:id() == 5)
    assert(E.Another:id() == 11)

    assert(E[3] == 'Foo')
    assert(E[2] == 'Bar')
    assert(E[4] == 'Qux')
    assert(E[5] == 'Baz')
    assert(E[11] == 'Another')
  end)

  it('should compare with itself', function()
    local E1 = Enum {
      'Foo',
      {'Qux', 11},
      'Bar',
      'Baz',
    }

    local E2 = Enum {
      'Foo',
      'Bar',
      'Baz',
    }

    assert(E1.Foo < E1.Qux)
    assert(E1.Baz > E1.Bar)

    assert(not (E1.Foo == E2.Foo))

    should_fail(function()
      return E1.Foo > E2.Foo
    end)

    should_fail(function()
      return E2.Bar >= E1.Foo
    end)
  end)

  it('should error when accessing invalid field', function()
    local E = Enum {
      'Foo',
      'Bar',
      'Baz',
    }

    should_fail(function()
      return E.foo
    end)

    should_fail(function()
      return E.bar
    end)
  end)
end)
