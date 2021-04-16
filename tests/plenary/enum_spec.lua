local Enum = require 'plenary.enum'

describe('Enum', function()
  it('should define member values starting at 1 and going up by 1', function()
    local names = {'Foo','Bar','Qux'}
    local E = Enum(names)
    for i, v in ipairs(names) do
      assert(E[v]:id() == i)
    end
  end)
  it('should define members both by name and value', function()
    local names = {'Foo','Bar','Qux'}
    local E = Enum(names)
    for i, v in ipairs(names) do
      assert(i == E[v]:id())
      assert(v == E[i])
    end
  end)
  it('should be able to define specific values for members', function()
    local E = Enum{
      {'Foo', 10},
      'Bar',
      'Qux'
    }
    assert(E.Foo:id() == 10)
    assert(E.Bar:id() == 11)
    assert(E.Qux:id() == 12)
  end)
end)
