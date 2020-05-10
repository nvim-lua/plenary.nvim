
local lu = require("luaunit")

local Path = require("plenary.path")
local test_harness = require("plenary.test_harness")

_ = [[
package.loaded['tests.plenary.path_spec'] = nil
require('tests.plenary.path_spec')
require('plenary.test_harness'):run(nil, nil, "TestPath")
]]

TestPath = {}

function TestPath:testReadme()
    local p = Path:new("README.md")

    lu.assertEquals(p.filename, "README.md")
end

function TestPath:testAbsolute()
    local p = Path:new("README.md")

    -- This is kind of a dumb thin since this is literally the way to call it...
    -- but oh well
    lu.assertEquals(p:absolute(), vim.fn.fnamemodify("README.md", ":p"))
end

function TestPath:testJoin()
    lu.assertEquals(Path:new("lua", "plenary"), Path:new("lua"):joinpath("plenary"))
end

function TestPath:testCoolDiv()
    lu.assertEquals(Path:new("lua", "plenary"), Path:new("lua") / "plenary")
end

function TestPath:testJoinWithPath()
    lu.assertEquals(Path:new("lua", "plenary"), Path:new("lua", Path:new("plenary")))
    lu.assertEquals(Path:new("lua", "plenary"), Path:new("lua"):joinpath(Path:new("plenary")))
end

function TestPath:testExists()
    lu.assertIsTrue(Path:new("README.md"):exists())
    lu.assertIsFalse(Path:new("asdf.md"):exists())
end

function TestPath:testIsDir()
    lu.assertIsTrue(Path:new("lua"):is_dir())
    lu.assertIsFalse(Path:new("asdf"):is_dir())
end

function TestPath:testCanBeCalledWithoutColon()
    -- This will work, cause we used a colon
    local with_colon = Path:new('lua')
    lu.assertIsTable(with_colon)

    local no_colon = Path.new('lua')
    lu.assertIsTable(no_colon)

    lu.assertEquals(with_colon, no_colon)
end

-- @sideeffect
function TestPath:testMkdir()
    local p = Path:new("_dir_not_exist")

    p:rmdir()
    lu.assertIsFalse(p:exists())

    p:mkdir()
    lu.assertIsTrue(p:exists())

    p:rmdir()
    lu.assertIsFalse(p:exists())
end
