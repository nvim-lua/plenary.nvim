local Path = require "plenary.path2"
local path = Path.path
-- local compat = require "plenary.compat"
local iswin = vim.loop.os_uname().sysname == "Windows_NT"

local hasshellslash = vim.fn.exists "+shellslash" == 1

---@param bool boolean
local function set_shellslash(bool)
  if hasshellslash then
    vim.o.shellslash = bool
  end
end

local function it_ssl(name, test_fn)
  if not hasshellslash then
    it(name, test_fn)
  else
    local orig = vim.o.shellslash
    vim.o.shellslash = true
    it(name .. " - shellslash", test_fn)

    vim.o.shellslash = false
    it(name .. " - noshellslash", test_fn)
    vim.o.shellslash = orig
  end
end

local function it_cross_plat(name, test_fn)
  if not iswin then
    it(name .. " - unix", test_fn)
  else
    it_ssl(name .. " - windows", test_fn)
  end
end

--- convert unix path into window paths
local function plat_path(p)
  if not iswin then
    return p
  end
  if hasshellslash and vim.o.shellslash then
    return p
  end
  return p:gsub("/", "\\")
end

describe("absolute", function()
  describe("unix", function()
    if iswin then
      return
    end
  end)

  describe("windows", function()
    if not iswin then
      return
    end

    describe("shellslash", function()
      set_shellslash(true)
    end)

    describe("noshellslash", function()
      set_shellslash(false)
    end)
  end)
end)

describe("Path", function()
  describe("filename", function()
    local function get_paths()
      local readme_path = vim.fn.fnamemodify("README.md", ":p")

      ---@type [string[]|string, string][]
      local paths = {
        { "README.md", "README.md" },
        { { "README.md" }, "README.md" },
        { { "lua", "..", "README.md" }, "lua/../README.md" },
        { { "lua/../README.md" }, "lua/../README.md" },
        { { "./lua/../README.md" }, "./lua/../README.md" },
        { "./lua//..//README.md", "./lua/../README.md" },
        { { readme_path }, readme_path },
      }

      return paths
    end

    local function test_filename(test_cases)
      for _, tc in ipairs(test_cases) do
        local input, expect = tc[1], tc[2]
        it(vim.inspect(input), function()
          local p = Path:new(input)
          assert.are.same(expect, p.filename)
        end)
      end
    end

    describe("unix", function()
      if iswin then
        return
      end
      test_filename(get_paths())
    end)

    describe("windows", function()
      if not iswin then
        return
      end

      local function get_windows_paths()
        local nossl = hasshellslash and not vim.o.shellslash

        ---@type [string[]|string, string][]
        local paths = {
          { [[C:\Documents\Newsletters\Summer2018.pdf]], [[C:/Documents/Newsletters/Summer2018.pdf]] },
          { [[C:\\Documents\\Newsletters\Summer2018.pdf]], [[C:/Documents/Newsletters/Summer2018.pdf]] },
          { { [[C:\Documents\Newsletters\Summer2018.pdf]] }, [[C:/Documents/Newsletters/Summer2018.pdf]] },
          { { [[C:/Documents/Newsletters/Summer2018.pdf]] }, [[C:/Documents/Newsletters/Summer2018.pdf]] },
          { { [[\\Server2\Share\Test\Foo.txt]] }, [[//Server2/Share/Test/Foo.txt]] },
          { { [[//Server2/Share/Test/Foo.txt]] }, [[//Server2/Share/Test/Foo.txt]] },
          { [[//Server2//Share//Test/Foo.txt]], [[//Server2/Share/Test/Foo.txt]] },
          { [[\\Server2\\Share\\Test\Foo.txt]], [[//Server2/Share/Test/Foo.txt]] },
          { { "C:", "lua", "..", "README.md" }, "C:lua/../README.md" },
          { { "C:/", "lua", "..", "README.md" }, "C:/lua/../README.md" },
          { "C:lua/../README.md", "C:lua/../README.md" },
          { "C:/lua/../README.md", "C:/lua/../README.md" },
          { [[foo/bar\baz]], [[foo/bar/baz]] },
          { [[\\.\C:\Test\Foo.txt]], [[//./C:/Test/Foo.txt]] },
          { [[\\?\C:\Test\Foo.txt]], [[//?/C:/Test/Foo.txt]] },
        }
        vim.list_extend(paths, get_paths())

        if nossl then
          paths = vim.tbl_map(function(tc)
            return { tc[1], (tc[2]:gsub("/", "\\")) }
          end, paths)
        end

        return paths
      end

      it("custom sep", function()
        local p = Path:new { "foo\\bar/baz", sep = "/" }
        assert.are.same(p.filename, "foo/bar/baz")
      end)

      describe("noshellslash", function()
        set_shellslash(false)
        test_filename(get_windows_paths())
      end)

      describe("shellslash", function()
        set_shellslash(true)
        test_filename(get_windows_paths())
      end)
    end)
  end)

  describe("absolute", function()
    local function get_paths()
      local readme_path = vim.fn.fnamemodify("README.md", ":p")

      ---@type [string[]|string, string, boolean][]
      local paths = {
        { "README.md", readme_path, false },
        { { "lua", "..", "README.md" }, readme_path, false },
        { { readme_path }, readme_path, true },
      }
      return paths
    end

    local function test_absolute(test_cases)
      for _, tc in ipairs(test_cases) do
        local input, expect, is_absolute = tc[1], tc[2], tc[3]
        it(vim.inspect(input), function()
          local p = Path:new(input)
          assert.are.same(expect, p:absolute())
          assert.are.same(is_absolute, p:is_absolute())
        end)
      end
    end

    describe("unix", function()
      if iswin then
        return
      end
      test_absolute(get_paths())
    end)

    describe("windows", function()
      if not iswin then
        return
      end

      local function get_windows_paths()
        local nossl = hasshellslash and not vim.o.shellslash
        local disk = path.root():match "^[%a]:"
        local readme_path = vim.fn.fnamemodify("README.md", ":p")

        ---@type [string[]|string, string, boolean][]
        local paths = {
          { [[C:\Documents\Newsletters\Summer2018.pdf]], [[C:/Documents/Newsletters/Summer2018.pdf]], true },
          { [[C:/Documents/Newsletters/Summer2018.pdf]], [[C:/Documents/Newsletters/Summer2018.pdf]], true },
          { [[\\Server2\Share\Test\Foo.txt]], [[//Server2/Share/Test/Foo.txt]], true },
          { [[//Server2/Share/Test/Foo.txt]], [[//Server2/Share/Test/Foo.txt]], true },
          { [[\\.\C:\Test\Foo.txt]], [[//./C:/Test/Foo.txt]], true },
          { [[\\?\C:\Test\Foo.txt]], [[//?/C:/Test/Foo.txt]], true },
          { readme_path, readme_path, true },
          { disk .. [[lua/../README.md]], readme_path, false },
          { { disk, "lua", "..", "README.md" }, readme_path, false },
        }
        vim.list_extend(paths, get_paths())

        if nossl then
          paths = vim.tbl_map(function(tc)
            return { tc[1], (tc[2]:gsub("/", "\\")), tc[3] }
          end, paths)
        end

        return paths
      end

      describe("shellslash", function()
        set_shellslash(true)
        test_absolute(get_windows_paths())
      end)

      describe("noshellslash", function()
        set_shellslash(false)
        test_absolute(get_windows_paths())
      end)
    end)
  end)

  it_cross_plat("can join paths by constructor or join path", function()
    assert.are.same(Path:new("lua", "plenary"), Path:new("lua"):joinpath "plenary")
  end)

  it_cross_plat("can join paths with /", function()
    assert.are.same(Path:new("lua", "plenary"), Path:new "lua" / "plenary")
  end)

  it_cross_plat("can join paths with paths", function()
    assert.are.same(Path:new("lua", "plenary"), Path:new("lua", Path:new "plenary"))
  end)

  it_cross_plat("inserts slashes", function()
    assert.are.same("lua" .. path.sep .. "plenary", Path:new("lua", "plenary").filename)
  end)

  describe(".exists()", function()
    it_cross_plat("finds files that exist", function()
      assert.are.same(true, Path:new("README.md"):exists())
    end)

    it_cross_plat("returns false for files that do not exist", function()
      assert.are.same(false, Path:new("asdf.md"):exists())
    end)
  end)

  describe(".is_dir()", function()
    it_cross_plat("should find directories that exist", function()
      assert.are.same(true, Path:new("lua"):is_dir())
    end)

    it_cross_plat("should return false when the directory does not exist", function()
      assert.are.same(false, Path:new("asdf"):is_dir())
    end)

    it_cross_plat("should not show files as directories", function()
      assert.are.same(false, Path:new("README.md"):is_dir())
    end)
  end)

  describe(".is_file()", function()
    it_cross_plat("should not allow directories", function()
      assert.are.same(true, not Path:new("lua"):is_file())
    end)

    it_cross_plat("should return false when the file does not exist", function()
      assert.are.same(true, not Path:new("asdf"):is_file())
    end)

    it_cross_plat("should show files as file", function()
      assert.are.same(true, Path:new("README.md"):is_file())
    end)
  end)

  describe(":new", function()
    it_cross_plat("can be called with or without colon", function()
      -- This will work, cause we used a colon
      local with_colon = Path:new "lua"
      local no_colon = Path.new "lua"

      assert.are.same(with_colon, no_colon)
    end)
  end)

  describe(":make_relative", function()
    local root = iswin and "c:\\" or "/"
    it_cross_plat("can take absolute paths and make them relative to the cwd", function()
      local p = Path:new { "lua", "plenary", "path.lua" }
      local absolute = vim.loop.cwd() .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative()
      assert.are.same(p.filename, relative)
    end)

    it_cross_plat("can take absolute paths and make them relative to a given path", function()
      local r = Path:new { root, "home", "prime" }
      local p = Path:new { "aoeu", "agen.lua" }
      local absolute = r.filename .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative(r.filename)
      assert.are.same(relative, p.filename)
    end)

    it_cross_plat("can take double separator absolute paths and make them relative to the cwd", function()
      local p = Path:new { "lua", "plenary", "path.lua" }
      local absolute = vim.loop.cwd() .. path.sep .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative()
      assert.are.same(relative, p.filename)
    end)

    it_cross_plat("can take double separator absolute paths and make them relative to a given path", function()
      local r = Path:new { root, "home", "prime" }
      local p = Path:new { "aoeu", "agen.lua" }
      local absolute = r.filename .. path.sep .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative(r.filename)
      assert.are.same(relative, p.filename)
    end)

    it_cross_plat("can take absolute paths and make them relative to a given path with trailing separator", function()
      local r = Path:new { root, "home", "prime" }
      local p = Path:new { "aoeu", "agen.lua" }
      local absolute = r.filename .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative(r.filename .. path.sep)
      assert.are.same(relative, p.filename)
    end)

    it_cross_plat("can take absolute paths and make them relative to the root directory", function()
      local p = Path:new { "home", "prime", "aoeu", "agen.lua" }
      local absolute = root .. p.filename
      local relative = Path:new(absolute):make_relative(root)
      assert.are.same(relative, p.filename)
    end)

    it_cross_plat("can take absolute paths and make them relative to themselves", function()
      local p = Path:new { root, "home", "prime", "aoeu", "agen.lua" }
      local relative = Path:new(p.filename):make_relative(p.filename)
      assert.are.same(relative, ".")
    end)

    it_cross_plat("should not truncate if path separator is not present after cwd", function()
      local cwd = "tmp" .. path.sep .. "foo"
      local p = Path:new { "tmp", "foo_bar", "fileb.lua" }
      local relative = Path:new(p.filename):make_relative(cwd)
      assert.are.same(p.filename, relative)
    end)

    it_cross_plat("should not truncate if path separator is not present after cwd and cwd ends in path sep", function()
      local cwd = "tmp" .. path.sep .. "foo" .. path.sep
      local p = Path:new { "tmp", "foo_bar", "fileb.lua" }
      local relative = Path:new(p.filename):make_relative(cwd)
      assert.are.same(p.filename, relative)
    end)
  end)

  describe(":normalize", function()
    local home = iswin and "C:/Users/test/" or "/home/test/"
    local tmp_lua = iswin and "C:/Windows/Temp/lua" or "/tmp/lua"

    it_cross_plat("can take path that has one character directories", function()
      local orig = iswin and "C:/Users/j/./p//path.lua" or "/home/j/./p//path.lua"
      local final = Path:new(orig):normalize()
      local expect = plat_path(iswin and "C:/Users/j/p/path.lua" or "/home/j/p/path.lua")
      assert.are.same(expect, final)
    end)

    it_cross_plat("can take paths with double separators change them to single separators", function()
      local orig = "lua//plenary/path.lua"
      local final = Path:new(orig):normalize()
      local expect = plat_path("lua/plenary/path.lua")
      assert.are.same(expect, final)
    end)

   --  -- this may be redundant since normalize just calls make_relative which is tested above
   --  it_cross_plat("can take absolute paths with double seps" .. "and make them relative with single seps", function()
   --    local orig = "/lua//plenary/path.lua"
   --    local final = Path:new(orig):normalize()
   --    local expect = plat_path("/lua/plenary/path.lua")
   --    assert.are.same(expect, final)
   --  end)

   --  it_cross_plat("can remove the .. in paths", function()
   --    local orig = "/lua//plenary/path.lua/foo/bar/../.."
   --    local final = Path:new(orig):normalize()
   --    local expect = plat_path("/lua/plenary/path.lua")
   --    assert.are.same(expect, final)
   --  end)

   --  it_cross_plat("can normalize relative paths", function()
   --    local orig = "lua/plenary/path.lua"
   --    local final = Path:new(orig):normalize()
   --    local expect = plat_path(orig)
   --    assert.are.same(expect, final)
   -- end)

   --  it_cross_plat("can normalize relative paths containing ..", function()
   --    local orig = "lua/plenary/path.lua/../path.lua"
   --    local final = Path:new(orig):normalize()
   --    local expect = plat_path("lua/plenary/path.lua")
   --    assert.are.same(expect, final)
   --  end)

   --  it_cross_plat("can normalize relative paths with initial ..", function()
   --    local p = Path:new "../lua/plenary/path.lua"
   --    p._cwd = tmp_lua
   --    local expect = plat_path("lua/plenary/path.lua")
   --    assert.are.same(expect, p:normalize())
   --  end)

    -- it_cross_plat("can normalize relative paths to absolute when initial .. count matches cwd parts", function()
    --   local p = Path:new "../../tmp/lua/plenary/path.lua"
    --   p._cwd = "/tmp/lua"
    --   assert.are.same("/tmp/lua/plenary/path.lua", p:normalize())
    -- end)

    -- it_cross_plat("can normalize ~ when file is within home directory (trailing slash)", function()
    --   local p = Path:new { home, "./test_file" }
    --   p.path.home = home
    --   p._cwd = tmp_lua
    --   assert.are.same("~/test_file", p:normalize())
    -- end)

    -- it_cross_plat("can normalize ~ when file is within home directory (no trailing slash)", function()
    --   local p = Path:new { home, "./test_file" }
    --   p.path.home = home
    --   p._cwd = tmp_lua
    --   assert.are.same("~/test_file", p:normalize())
    -- end)

    -- it_cross_plat("handles usernames with a dash at the end", function()
    --   local p = Path:new { home, "test_file" }
    --   p.path.home = home
    --   p._cwd = tmp_lua
    --   assert.are.same("~/test_file", p:normalize())
    -- end)

    -- it_cross_plat("handles filenames with the same prefix as the home directory", function()
    --   local pstr = iswin and "C:/Users/test.old/test_file" or "/home/test.old/test_file"
    --   local p = Path:new(pstr)
    --   p.path.home = home
    --   assert.are.same(pstr, p:normalize())
    -- end)
  end)

  -- describe(":shorten", function()
  --   it_cross_plat("can shorten a path", function()
  --     local long_path = "/this/is/a/long/path"
  --     local short_path = Path:new(long_path):shorten()
  --     assert.are.same(short_path, "/t/i/a/l/path")
  --   end)

  --   it_cross_plat("can shorten a path's components to a given length", function()
  --     local long_path = "/this/is/a/long/path"
  --     local short_path = Path:new(long_path):shorten(2)
  --     assert.are.same(short_path, "/th/is/a/lo/path")

  --     -- without the leading /
  --     long_path = "this/is/a/long/path"
  --     short_path = Path:new(long_path):shorten(3)
  --     assert.are.same(short_path, "thi/is/a/lon/path")

  --     -- where len is greater than the length of the final component
  --     long_path = "this/is/an/extremely/long/path"
  --     short_path = Path:new(long_path):shorten(5)
  --     assert.are.same(short_path, "this/is/an/extre/long/path")
  --   end)

  --   it_cross_plat("can shorten a path's components when excluding parts", function()
  --     local long_path = "/this/is/a/long/path"
  --     local short_path = Path:new(long_path):shorten(nil, { 1, -1 })
  --     assert.are.same(short_path, "/this/i/a/l/path")

  --     -- without the leading /
  --     long_path = "this/is/a/long/path"
  --     short_path = Path:new(long_path):shorten(nil, { 1, -1 })
  --     assert.are.same(short_path, "this/i/a/l/path")

  --     -- where excluding positions greater than the number of parts
  --     long_path = "this/is/an/extremely/long/path"
  --     short_path = Path:new(long_path):shorten(nil, { 2, 4, 6, 8 })
  --     assert.are.same(short_path, "t/is/a/extremely/l/path")

  --     -- where excluding positions less than the negation of the number of parts
  --     long_path = "this/is/an/extremely/long/path"
  --     short_path = Path:new(long_path):shorten(nil, { -2, -4, -6, -8 })
  --     assert.are.same(short_path, "this/i/an/e/long/p")
  --   end)

  --   it_cross_plat("can shorten a path's components to a given length and exclude positions", function()
  --     local long_path = "/this/is/a/long/path"
  --     local short_path = Path:new(long_path):shorten(2, { 1, -1 })
  --     assert.are.same(short_path, "/this/is/a/lo/path")

  --     long_path = "this/is/a/long/path"
  --     short_path = Path:new(long_path):shorten(3, { 2, -2 })
  --     assert.are.same(short_path, "thi/is/a/long/pat")

  --     long_path = "this/is/an/extremely/long/path"
  --     short_path = Path:new(long_path):shorten(5, { 3, -3 })
  --     assert.are.same(short_path, "this/is/an/extremely/long/path")
  --   end)
  -- end)

  -- describe("mkdir / rmdir", function()
  --   it_cross_plat("can create and delete directories", function()
  --     local p = Path:new "_dir_not_exist"

  --     p:rmdir()
  --     assert(not p:exists(), "After rmdir, it should not exist")

  --     p:mkdir()
  --     assert(p:exists())

  --     p:rmdir()
  --     assert(not p:exists())
  --   end)

  --   it_cross_plat("fails when exists_ok is false", function()
  --     local p = Path:new "lua"
  --     assert(not pcall(p.mkdir, p, { exists_ok = false }))
  --   end)

  --   it_cross_plat("fails when parents is not passed", function()
  --     local p = Path:new("impossible", "dir")
  --     assert(not pcall(p.mkdir, p, { parents = false }))
  --     assert(not p:exists())
  --   end)

  --   it_cross_plat("can create nested directories", function()
  --     local p = Path:new("impossible", "dir")
  --     assert(pcall(p.mkdir, p, { parents = true }))
  --     assert(p:exists())

  --     p:rmdir()
  --     Path:new("impossible"):rmdir()
  --     assert(not p:exists())
  --     assert(not Path:new("impossible"):exists())
  --   end)
  -- end)

  -- describe("touch", function()
  --   it_cross_plat("can create and delete new files", function()
  --     local p = Path:new "test_file.lua"
  --     assert(pcall(p.touch, p))
  --     assert(p:exists())

  --     p:rm()
  --     assert(not p:exists())
  --   end)

  --   it_cross_plat("does not effect already created files but updates last access", function()
  --     local p = Path:new "README.md"
  --     local last_atime = p:_stat().atime.sec
  --     local last_mtime = p:_stat().mtime.sec

  --     local lines = p:readlines()

  --     assert(pcall(p.touch, p))
  --     print(p:_stat().atime.sec > last_atime)
  --     print(p:_stat().mtime.sec > last_mtime)
  --     assert(p:exists())

  --     assert.are.same(lines, p:readlines())
  --   end)

  --   it_cross_plat("does not create dirs if nested in none existing dirs and parents not set", function()
  --     local p = Path:new { "nested", "nested2", "test_file.lua" }
  --     assert(not pcall(p.touch, p, { parents = false }))
  --     assert(not p:exists())
  --   end)

  --   it_cross_plat("does create dirs if nested in none existing dirs", function()
  --     local p1 = Path:new { "nested", "nested2", "test_file.lua" }
  --     local p2 = Path:new { "nested", "asdf", ".hidden" }
  --     local d1 = Path:new { "nested", "dir", ".hidden" }
  --     assert(pcall(p1.touch, p1, { parents = true }))
  --     assert(pcall(p2.touch, p2, { parents = true }))
  --     assert(pcall(d1.mkdir, d1, { parents = true }))
  --     assert(p1:exists())
  --     assert(p2:exists())
  --     assert(d1:exists())

  --     Path:new({ "nested" }):rm { recursive = true }
  --     assert(not p1:exists())
  --     assert(not p2:exists())
  --     assert(not d1:exists())
  --     assert(not Path:new({ "nested" }):exists())
  --   end)
  -- end)

  -- describe("rename", function()
  --   it_cross_plat("can rename a file", function()
  --     local p = Path:new "a_random_filename.lua"
  --     assert(pcall(p.touch, p))
  --     assert(p:exists())

  --     assert(pcall(p.rename, p, { new_name = "not_a_random_filename.lua" }))
  --     assert.are.same("not_a_random_filename.lua", p.filename)

  --     p:rm()
  --   end)

  --   it_cross_plat("can handle an invalid filename", function()
  --     local p = Path:new "some_random_filename.lua"
  --     assert(pcall(p.touch, p))
  --     assert(p:exists())

  --     assert(not pcall(p.rename, p, { new_name = "" }))
  --     assert(not pcall(p.rename, p))
  --     assert.are.same("some_random_filename.lua", p.filename)

  --     p:rm()
  --   end)

  --   it_cross_plat("can move to parent dir", function()
  --     local p = Path:new "some_random_filename.lua"
  --     assert(pcall(p.touch, p))
  --     assert(p:exists())

  --     assert(pcall(p.rename, p, { new_name = "../some_random_filename.lua" }))
  --     assert.are.same(vim.loop.fs_realpath(Path:new("../some_random_filename.lua"):absolute()), p:absolute())

  --     p:rm()
  --   end)

  --   it_cross_plat("cannot rename to an existing filename", function()
  --     local p1 = Path:new "a_random_filename.lua"
  --     local p2 = Path:new "not_a_random_filename.lua"
  --     assert(pcall(p1.touch, p1))
  --     assert(pcall(p2.touch, p2))
  --     assert(p1:exists())
  --     assert(p2:exists())

  --     assert(not pcall(p1.rename, p1, { new_name = "not_a_random_filename.lua" }))
  --     assert.are.same(p1.filename, "a_random_filename.lua")

  --     p1:rm()
  --     p2:rm()
  --   end)
  -- end)

  -- describe("copy", function()
  --   it_cross_plat("can copy a file", function()
  --     local p1 = Path:new "a_random_filename.rs"
  --     local p2 = Path:new "not_a_random_filename.rs"
  --     assert(pcall(p1.touch, p1))
  --     assert(p1:exists())

  --     assert(pcall(p1.copy, p1, { destination = "not_a_random_filename.rs" }))
  --     assert.are.same(p1.filename, "a_random_filename.rs")
  --     assert.are.same(p2.filename, "not_a_random_filename.rs")

  --     p1:rm()
  --     p2:rm()
  --   end)

  --   it_cross_plat("can copy to parent dir", function()
  --     local p = Path:new "some_random_filename.lua"
  --     assert(pcall(p.touch, p))
  --     assert(p:exists())

  --     assert(pcall(p.copy, p, { destination = "../some_random_filename.lua" }))
  --     assert(pcall(p.exists, p))

  --     p:rm()
  --     Path:new(vim.loop.fs_realpath "../some_random_filename.lua"):rm()
  --   end)

  --   it_cross_plat("cannot copy an existing file if override false", function()
  --     local p1 = Path:new "a_random_filename.rs"
  --     local p2 = Path:new "not_a_random_filename.rs"
  --     assert(pcall(p1.touch, p1))
  --     assert(pcall(p2.touch, p2))
  --     assert(p1:exists())
  --     assert(p2:exists())

  --     assert(pcall(p1.copy, p1, { destination = "not_a_random_filename.rs", override = false }))
  --     assert.are.same(p1.filename, "a_random_filename.rs")
  --     assert.are.same(p2.filename, "not_a_random_filename.rs")

  --     p1:rm()
  --     p2:rm()
  --   end)

  --   it_cross_plat("fails when copying folders non-recursively", function()
  --     local src_dir = Path:new "src"
  --     src_dir:mkdir()
  --     src_dir:joinpath("file1.lua"):touch()

  --     local trg_dir = Path:new "trg"
  --     local status = xpcall(function()
  --       src_dir:copy { destination = trg_dir, recursive = false }
  --     end, function() end)
  --     -- failed as intended
  --     assert(status == false)

  --     src_dir:rm { recursive = true }
  --   end)

  --   it_cross_plat("can copy directories recursively", function()
  --     -- vim.tbl_flatten doesn't work here as copy doesn't return a list
  --     local flatten
  --     flatten = function(ret, t)
  --       for _, v in pairs(t) do
  --         if type(v) == "table" then
  --           flatten(ret, v)
  --         else
  --           table.insert(ret, v)
  --         end
  --       end
  --     end

  --     -- setup directories
  --     local src_dir = Path:new "src"
  --     local trg_dir = Path:new "trg"
  --     src_dir:mkdir()

  --     -- set up sub directory paths for creation and testing
  --     local sub_dirs = { "sub_dir1", "sub_dir1/sub_dir2" }
  --     local src_dirs = { src_dir }
  --     local trg_dirs = { trg_dir }
  --     -- {src, trg}_dirs is a table with all directory levels by {src, trg}
  --     for _, dir in ipairs(sub_dirs) do
  --       table.insert(src_dirs, src_dir:joinpath(dir))
  --       table.insert(trg_dirs, trg_dir:joinpath(dir))
  --     end

  --     -- generate {file}_{level}.lua on every directory level in src
  --     -- src
  --     -- ├── file1_1.lua
  --     -- ├── file2_1.lua
  --     -- ├── .file3_1.lua
  --     -- └── sub_dir1
  --     --     ├── file1_2.lua
  --     --     ├── file2_2.lua
  --     --     ├── .file3_2.lua
  --     --     └── sub_dir2
  --     --         ├── file1_3.lua
  --     --         ├── file2_3.lua
  --     --         └── .file3_3.lua
  --     local files = { "file1", "file2", ".file3" }
  --     for _, file in ipairs(files) do
  --       for level, dir in ipairs(src_dirs) do
  --         local p = dir:joinpath(file .. "_" .. level .. ".lua")
  --         assert(pcall(p.touch, p, { parents = true, exists_ok = true }))
  --         assert(p:exists())
  --       end
  --     end

  --     for _, hidden in ipairs { true, false } do
  --       -- override = `false` should NOT copy as it was copied beforehand
  --       for _, override in ipairs { true, false } do
  --         local success = src_dir:copy { destination = trg_dir, recursive = true, override = override, hidden = hidden }
  --         -- the files are already created because we iterate first with `override=true`
  --         -- hence, we test here that no file ops have been committed: any value in tbl of tbls should be false
  --         if not override then
  --           local file_ops = {}
  --           flatten(file_ops, success)
  --           -- 3 layers with at at least 2 and at most 3 files (`hidden = true`)
  --           local num_files = not hidden and 6 or 9
  --           assert(#file_ops == num_files)
  --           for _, op in ipairs(file_ops) do
  --             assert(op == false)
  --           end
  --         else
  --           for _, file in ipairs(files) do
  --             for level, dir in ipairs(trg_dirs) do
  --               local p = dir:joinpath(file .. "_" .. level .. ".lua")
  --               -- file 3 is hidden
  --               if not (file == files[3]) then
  --                 assert(p:exists())
  --               else
  --                 assert(p:exists() == hidden)
  --               end
  --             end
  --           end
  --         end
  --         -- only clean up once we tested that we dont want to copy
  --         -- if `override=true`
  --         if not override then
  --           trg_dir:rm { recursive = true }
  --         end
  --       end
  --     end

  --     src_dir:rm { recursive = true }
  --   end)
  -- end)

  --   describe("parents", function()
  --     it_cross_plat("should extract the ancestors of the path", function()
  --       local p = Path:new(vim.loop.cwd())
  --       local parents = p:parents()
  --       assert(compat.islist(parents))
  --       for _, parent in pairs(parents) do
  --         assert.are.same(type(parent), "string")
  --       end
  --     end)
  --     it_cross_plat("should return itself if it corresponds to path.root", function()
  --       local p = Path:new(Path.path.root(vim.loop.cwd()))
  --       assert.are.same(p:parent(), p)
  --     end)
  --   end)

  --   describe("read parts", function()
  --     it_cross_plat("should read head of file", function()
  --       local p = Path:new "LICENSE"
  --       local data = p:head()
  --       local should = [[MIT License

  -- Copyright (c) 2020 TJ DeVries

  -- Permission is hereby granted, free of charge, to any person obtaining a copy
  -- of this software and associated documentation files (the "Software"), to deal
  -- in the Software without restriction, including without limitation the rights
  -- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  -- copies of the Software, and to permit persons to whom the Software is
  -- furnished to do so, subject to the following conditions:]]
  --       assert.are.same(should, data)
  --     end)

  --     it_cross_plat("should read the first line of file", function()
  --       local p = Path:new "LICENSE"
  --       local data = p:head(1)
  --       local should = [[MIT License]]
  --       assert.are.same(should, data)
  --     end)

  --     it_cross_plat("head should max read whole file", function()
  --       local p = Path:new "LICENSE"
  --       local data = p:head(1000)
  --       local should = [[MIT License

  -- Copyright (c) 2020 TJ DeVries

  -- Permission is hereby granted, free of charge, to any person obtaining a copy
  -- of this software and associated documentation files (the "Software"), to deal
  -- in the Software without restriction, including without limitation the rights
  -- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  -- copies of the Software, and to permit persons to whom the Software is
  -- furnished to do so, subject to the following conditions:

  -- The above copyright notice and this permission notice shall be included in all
  -- copies or substantial portions of the Software.

  -- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  -- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  -- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  -- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  -- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  -- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  -- SOFTWARE.]]
  --       assert.are.same(should, data)
  --     end)

  --     it_cross_plat("should read tail of file", function()
  --       local p = Path:new "LICENSE"
  --       local data = p:tail()
  --       local should = [[The above copyright notice and this permission notice shall be included in all
  -- copies or substantial portions of the Software.

  -- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  -- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  -- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  -- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  -- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  -- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  -- SOFTWARE.]]
  --       assert.are.same(should, data)
  --     end)

  --     it_cross_plat("should read the last line of file", function()
  --       local p = Path:new "LICENSE"
  --       local data = p:tail(1)
  --       local should = [[SOFTWARE.]]
  --       assert.are.same(should, data)
  --     end)

  --     it_cross_plat("tail should max read whole file", function()
  --       local p = Path:new "LICENSE"
  --       local data = p:tail(1000)
  --       local should = [[MIT License

  -- Copyright (c) 2020 TJ DeVries

  -- Permission is hereby granted, free of charge, to any person obtaining a copy
  -- of this software and associated documentation files (the "Software"), to deal
  -- in the Software without restriction, including without limitation the rights
  -- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  -- copies of the Software, and to permit persons to whom the Software is
  -- furnished to do so, subject to the following conditions:

  -- The above copyright notice and this permission notice shall be included in all
  -- copies or substantial portions of the Software.

  -- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  -- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  -- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  -- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  -- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  -- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  -- SOFTWARE.]]
  --       assert.are.same(should, data)
  --     end)
  --   end)

  --   describe("readbyterange", function()
  --     it_cross_plat("should read bytes at given offset", function()
  --       local p = Path:new "LICENSE"
  --       local data = p:readbyterange(13, 10)
  --       local should = "Copyright "
  --       assert.are.same(should, data)
  --     end)

  --     it_cross_plat("supports negative offset", function()
  --       local p = Path:new "LICENSE"
  --       local data = p:readbyterange(-10, 10)
  --       local should = "SOFTWARE.\n"
  --       assert.are.same(should, data)
  --     end)
  --   end)
end)
