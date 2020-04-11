
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


test_harness:run()
