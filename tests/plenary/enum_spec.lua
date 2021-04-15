local Enum = require 'plenary.enum'

describe('Enum', function()
  it('should define member values starting at 1 and going up by 1', function()
    local names = {'Foo','Bar','Qux'}
    local E = Enum(names)
    for i, v in ipairs(names) do
      assert(i == E[v])
    end
  end)
  it('should define members both by name and value', function()
    local names = {'Foo','Bar','Qux'}
    local E = Enum(names)
    for i, v in ipairs(names) do
      assert(i == E[v])
      assert(v == E[i])
    end
  end)
  it('should be able to define specific values for members', function()
    local E = Enum{
      {'Foo', 10},
      'Bar',
      'Qux'
    }
    assert(E.Foo == 10)
    assert(E.Bar == 11)
    assert(E.Qux == 12)
  end)
end)
