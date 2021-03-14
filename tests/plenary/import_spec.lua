local import = require('plenary.import')

local eq = assert.are

describe('import', function()
  it('should be able to glob import', function()
    import { "*", from = "plenary.filetype" }

    assert(type(_get_extension_parts), "function")
  end)

  it('should be able to import from local module', function()
    local M = {}
    function M.hello() return 'hello' end

    import { "*", from = M }

    eq(hello(), 'hello')
  end)

  it('should be able to import into a local function', function()
    local M = {}
    function M.hello() return 'hello' end

    local function test()
      eq(hello(), 'hello')
    end

    import { "*", from = M, into = test }

    test()
  end)

  it('should be able to import with a namespace', function()
    import { from = "plenary.filetype", as = "ft" }

    assert(type(ft) == "table")
    assert(type(ft._get_extension_parts), "function")
  end)

  it('should be able to import only one thing', function()
    local M = {}
    function M.hello() return 'hello' end
    function M.dont_import() end

    import { "hello", from = M, as = "module"}

    eq(type(hello), 'function')
    eq(hello(), 'hello')
    eq(type(dont_import), 'nil')
    eq(type(module), 'table')
  end)
end)
