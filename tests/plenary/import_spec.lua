local eq = assert.are.same

describe('import', function()
  it('should be able to glob import', function()
    local import = require('plenary.import')

    import { "*", from = "plenary.filetype" }

    assert(type(_get_extension_parts), "function")
  end)

  it('should be able to import from local module', function()
    local import = require('plenary.import')

    local M = {}
    function M.hello() return 'hello' end

    import { "*", from = M }

    eq(hello(), 'hello')
  end)

  it('should be able to import into a local function', function()
    local import = require('plenary.import')

    local M = {}
    function M.hello() return 'hello' end

    local function test()
      eq(hello(), 'hello')
    end

    import { "*", from = M, into = test }

    test()
  end)

  it('should be able to import with a namespace', function()
    local import = require('plenary.import')

    import { from = "plenary.filetype", as = "ft" }

    assert(type(ft) == "table")
    assert(type(ft._get_extension_parts), "function")
  end)
end)
