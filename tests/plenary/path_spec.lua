
local test_harness = require("plenary.test_harness")
local lu = require("plenary.luaunit")

local path = require("plenary.path")

TestPath = {}

function TestPath:testReadme()
    local p = path:new("README.md")

    lu.assertEquals(p.raw, "README.md")
end

function TestPath:testAbsolute()
    local p = path:new("README.md")

    -- This is kind of a dumb thin since this is literally the way to call it...
    -- but oh well
    lu.assertEquals(p:absolute(), vim.fn.fnamemodify("README.md", ":p"))
end

function TestPath:testJoin()
    lu.assertEquals(path:new("lua", "plenary"), path:new("lua"):joinpath("plenary"))
end

function TestPath:testCoolDiv()
    lu.assertEquals(path:new("lua", "plenary"), path:new("lua") / "plenary")
end

function TestPath:testJoinWithPath()
    lu.assertEquals(path:new("lua", "plenary"), path:new("lua", path:new("plenary")))
    lu.assertEquals(path:new("lua", "plenary"), path:new("lua"):joinpath(path:new("plenary")))
end

function TestPath:testExists()
    lu.assertIsTrue(path:new("README.md"):exists())
    lu.assertIsFalse(path:new("asdf.md"):exists())
end

function TestPath:testIsDir()
    lu.assertIsTrue(path:new("lua"):is_dir())
    lu.assertIsFalse(path:new("asdf"):is_dir())
end

function TestPath:testMustCalledWithColon()
    -- This will work, cause we used a colon
    lu.assertIsTable(path:new('lua'))
    -- This will error, since we did not
    lu.assertError(path.new, 'lua')
end

function TestPath:testMkdir()
    local p = path:new("_dir_not_exist")

    p:rmdir()
    lu.assertIsFalse(p:exists())

    p:mkdir()
    lu.assertIsTrue(p:exists())

    p:rmdir()
    lu.assertIsFalse(p:exists())
end

test_harness:run()
