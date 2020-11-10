require('plenary.test_harness'):setup_busted()

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
      assert.are.same(false, Path:new("lua"):is_file())
    end)

    it('should return false when the file does not exist', function()
      assert.are.same(false, Path:new("asdf"):is_file())
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

    pending('can create nested directories', function()
      local p = Path:new("impossible", "dir")
      assert(pcall(p.mkdir, p, { parents = true }))
      assert(p:exists())
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
