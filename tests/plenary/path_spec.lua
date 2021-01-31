local Path = require("plenary.path")
local path = Path.path

describe('Path', function()
  it('should find valid files', function()
    local p = Path:new("README.md")
    assert(p.filename == "README.md", p.filename)
    assert.are.same(p.filename, "README.md")
  end)

  describe('absolute', function()
    it('.absolute()', function()
      local p = Path:new { "README.md" , sep = '/'}
      assert.are.same(p:absolute(), vim.fn.fnamemodify("README.md", ":p"))
    end)

    it('can determine absolute paths', function()
      local p = Path:new { "/home/asdfasdf/" , sep = '/'}
      assert(p:is_absolute(), "Is absolute")
      assert(p:absolute() == p.filename)
    end)

    it('can determine non absolute paths', function()
      local p = Path:new { "./home/tj/" , sep = '/'}
      assert(not p:is_absolute(), "Is absolute")
    end)
  end)

  it('can join paths by constructor or join path', function()
    assert.are.same(Path:new("lua", "plenary"), Path:new("lua"):joinpath("plenary"))
  end)

  it('can join paths with /', function()
    assert.are.same(Path:new("lua", "plenary"), Path:new("lua") / "plenary")
  end)

  it('can join paths with paths', function()
    assert.are.same(Path:new("lua", "plenary"), Path:new("lua", Path:new("plenary")))
  end)

  it('inserts slashes', function()
    assert.are.same(
    'lua' .. path.sep .. 'plenary',
      Path:new("lua", "plenary").filename
    )
  end)

  describe('.exists()', function()
    it('finds files that exist', function()
      assert.are.same(true, Path:new("README.md"):exists())
    end)

    it('returns false for files that do not exist', function()
      assert.are.same(false, Path:new("asdf.md"):exists())
    end)
  end)

  describe('.is_dir()', function()
    it('should find directories that exist', function()
      assert.are.same(true, Path:new("lua"):is_dir())
    end)

    it('should return false when the directory does not exist', function()
      assert.are.same(false, Path:new("asdf"):is_dir())
    end)

    it('should not show files as directories', function()
      assert.are.same(false, Path:new("README.md"):is_dir())
    end)
  end)

  describe('.is_file()', function()
    it('should not allow directories', function()
      assert.are.same(true, not Path:new("lua"):is_file())
    end)

    it('should return false when the file does not exist', function()
      assert.are.same(true, not Path:new("asdf"):is_file())
    end)

    it('should show files as file', function()
      assert.are.same(true, Path:new("README.md"):is_file())
    end)
  end)

  describe(':new', function()
    it('can be called with or without colon', function()
    -- This will work, cause we used a colon
    local with_colon = Path:new('lua')
    local no_colon = Path.new('lua')

    assert.are.same(with_colon, no_colon)
    end)
  end)

  describe('mkdir / rmdir', function()
    it('can create and delete directories', function()
      local p = Path:new("_dir_not_exist")

      p:rmdir()
      assert(not p:exists(), "After rmdir, it should not exist")

      p:mkdir()
      assert(p:exists())

      p:rmdir()
      assert(not p:exists())
    end)

    it('fails when exists_ok is false', function()
      local p = Path:new("lua")
      assert(not pcall(p.mkdir, p, { exists_ok = false }))
    end)

    it('fails when parents is not passed', function()
      local p = Path:new("impossible", "dir")
      assert(not pcall(p.mkdir, p, { parents = false }))
      assert(not p:exists())
    end)

    it('can create nested directories', function()
      local p = Path:new("impossible", "dir")
      assert(pcall(p.mkdir, p, { parents = true }))
      assert(p:exists())

      p:rmdir()
      Path:new('impossible'):rmdir()
      assert(not p:exists())
      assert(not Path:new('impossible'):exists())
    end)
  end)

  describe('touch', function()
    it('can create and delete new files', function()
      local p = Path:new("test_file.lua")
      assert(pcall(p.touch, p))
      assert(p:exists())

      p:rm()
      assert(not p:exists())
    end)

    it('does not effect already created files but updates last access', function()
      local p = Path:new("README.md")
      local last_atime = p:_stat().atime.sec
      local last_mtime = p:_stat().mtime.sec

      local lines = p:readlines()

      assert(pcall(p.touch, p))
      print(p:_stat().atime.sec > last_atime)
      print(p:_stat().mtime.sec > last_mtime)
      assert(p:exists())

      assert.are.same(lines, p:readlines())
    end)

    it('does not create dirs if nested in none existing dirs and parents not set', function()
      local p = Path:new({ "nested", "nested2", "test_file.lua" })
      assert(not pcall(p.touch, p, { parents = false }))
      assert(not p:exists())
    end)

    it('does create dirs if nested in none existing dirs', function()
      local p1 = Path:new({ "nested", "nested2", "test_file.lua" })
      local p2 = Path:new({ "nested", "asdf", ".hidden" })
      assert(pcall(p1.touch, p1, { parents = true }))
      assert(pcall(p2.touch, p2, { parents = true }))
      assert(p1:exists())
      assert(p2:exists())

      Path:new({ "nested" }):rm({ recursive = true })
      assert(not p1:exists())
      assert(not p2:exists())
      assert(not Path:new({ "nested" }):exists())
    end)
  end)

  describe('read parts', function()
    it('should read head of file', function()
      local p = Path:new('LICENSE')
      local data = p:head()
      local should = [[MIT License

Copyright (c) 2020 TJ DeVries

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:]]
      assert.are.same(should, data)
    end)

    it('should read the first line of file', function()
      local p = Path:new('LICENSE')
      local data = p:head(1)
      local should = [[MIT License]]
      assert.are.same(should, data)
    end)

    it('head should max read whole file', function()
      local p = Path:new('LICENSE')
      local data = p:head(1000)
      local should = [[MIT License

Copyright (c) 2020 TJ DeVries

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.]]
      assert.are.same(should, data)
    end)

    it('should read tail of file', function()
      local p = Path:new('LICENSE')
      local data = p:tail()
      local should = [[The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.]]
      assert.are.same(should, data)
    end)

    it('should read the last line of file', function()
      local p = Path:new('LICENSE')
      local data = p:tail(1)
      local should = [[SOFTWARE.]]
      assert.are.same(should, data)
    end)

    it('tail should max read whole file', function()
      local p = Path:new('LICENSE')
      local data = p:tail(1000)
      local should = [[MIT License

Copyright (c) 2020 TJ DeVries

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.]]
      assert.are.same(should, data)
    end)
  end)
end)


-- function TestPath:testIsDir()
-- end

-- function TestPath:testCanBeCalledWithoutColon()
-- end

-- -- @sideeffect
-- function TestPath:testMkdir()
-- end
