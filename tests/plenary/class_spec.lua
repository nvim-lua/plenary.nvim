local eq = assert.are.same
local class = require('plenary.class')
local struct, trait, impl = class.struct, class.trait, class.impl

describe('class', function()
  it('should create struct', function()
    local Alive = trait {  }
    Alive.is_alive()
    Alive.happy()
    function Alive:default()
      return "this is default"
    end

    dump(Alive)

    local Person = struct {
      __init = function(name, age)
        return {name = name, age = age}
      end
    }

    function Person:say_hello()
      return 'hello ' .. self.name
    end

    impl(Alive, Person, {
      is_alive = function(self)
        print('found is alive')
        return false
      end,
      happy = function(self)
        print('found is happy')
        return true
      end
    })

    local me = Person('ober', 1000000)
    eq(me:say_hello(), 'hello ober')

    eq(me:is_alive(), false)

    eq(me:default(), 'this is default')
  end)
end)
