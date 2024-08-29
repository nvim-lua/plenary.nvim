local Path = require "plenary.path2"
local path = Path.path
local compat = require "plenary.compat"
local iswin = vim.loop.os_uname().sysname == "Windows_NT"

local hasshellslash = vim.fn.exists "+shellslash" == 1

---@param bool boolean
local function set_shellslash(bool)
  if hasshellslash then
    vim.o.shellslash = bool
  end
end

local function it_cross_plat(name, test_fn)
  if not iswin then
    it(name .. " - unix", test_fn)
  else
    if not hasshellslash then
      it(name .. " - windows", test_fn)
    else
      local orig = vim.o.shellslash
      vim.o.shellslash = true
      it(name .. " - windows (shellslash)", test_fn)

      vim.o.shellslash = false
      it(name .. " - windows (noshellslash)", test_fn)
      vim.o.shellslash = orig
    end
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

describe("Path2", function()
  describe("filename", function()
    local function get_paths()
      local readme_path = vim.fn.fnamemodify("README.md", ":p")
      local license_path = vim.fn.fnamemodify("LICENSE", ":p")

      ---@type [string[]|string, string][]
      local paths = {
        { "README.md", "README.md" },
        { { "README.md" }, "README.md" },
        { { "lua", "..", "README.md" }, "lua/../README.md" },
        { { "lua/../README.md" }, "lua/../README.md" },
        { { "./lua/../README.md" }, "lua/../README.md" },
        { "./lua//..//README.md", "lua/../README.md" },
        { { "foo", "bar", "baz" }, "foo/bar/baz" },
        { "foo/bar/", "foo/bar" },
        { { readme_path }, readme_path },
        { { readme_path, license_path }, license_path }, -- takes only the last abs path
        { ".", "." },
      }

      return paths
    end

    local function test_filename(test_cases)
      for _, tc in ipairs(test_cases) do
        local input, expect = tc[1], tc[2]
        it(vim.inspect(input), function()
          local p = Path:new(input)
          assert.are.same(expect, p.filename, p.relparts)
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
          { [[//Server2/Share/Test/Foo.txt]], [[//Server2/Share/Test/Foo.txt]] },
          { [[\\Server2\Share\Test\Foo.txt]], [[//Server2/Share/Test/Foo.txt]] },
          { { "C:", "lua", "..", "README.md" }, "C:lua/../README.md" },
          { { "C:/", "lua", "..", "README.md" }, "C:/lua/../README.md" },
          { "C:lua/../README.md", "C:lua/../README.md" },
          { "C:/lua/../README.md", "C:/lua/../README.md" },
          { [[foo/bar\baz]], [[foo/bar/baz]] },
          { [[\\.\C:\Test\Foo.txt]], [[//./C:/Test/Foo.txt]] },
          { [[\\?\C:\Test\Foo.txt]], [[//?/C:/Test/Foo.txt]] },
          { [[\\.\UNC\Server\Share\Test\Foo.txt]], [[//./UNC/Server/Share/Test/Foo.txt]] },
          { [[\\?\UNC\Server\Share\Test\Foo.txt]], [[//?/UNC/Server/Share/Test/Foo.txt]] },
          { "/foo/bar/baz", "foo/bar/baz" },
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
        local drive = Path:new(vim.fn.getcwd()).drv
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
          { drive .. [[lua/../README.md]], readme_path, false },
          { { drive, "lua", "..", "README.md" }, readme_path, false },
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
      assert.is_true(Path:new("README.md"):exists())
    end)

    it_cross_plat("returns false for files that do not exist", function()
      assert.is_false(Path:new("asdf.md"):exists())
    end)
  end)

  describe(".is_dir()", function()
    it_cross_plat("should find directories that exist", function()
      assert.is_true(Path:new("lua"):is_dir())
    end)

    it_cross_plat("should return false when the directory does not exist", function()
      assert.is_false(Path:new("asdf"):is_dir())
    end)

    it_cross_plat("should not show files as directories", function()
      assert.is_false(Path:new("README.md"):is_dir())
    end)
  end)

  describe(".is_file()", function()
    it_cross_plat("should not allow directories", function()
      assert.is_true(not Path:new("lua"):is_file())
    end)

    it_cross_plat("should return false when the file does not exist", function()
      assert.is_true(not Path:new("asdf"):is_file())
    end)

    it_cross_plat("should show files as file", function()
      assert.is_true(Path:new("README.md"):is_file())
    end)
  end)

  describe(":make_relative", function()
    local root = function()
      if not iswin then
        return "/"
      end
      if hasshellslash and vim.o.shellslash then
        return "C:/"
      end
      return "C:\\"
    end

    it_cross_plat("can take absolute paths and make them relative to the cwd", function()
      local p = Path:new { "lua", "plenary", "path.lua" }
      local absolute = vim.fn.getcwd() .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative()
      assert.are.same(p.filename, relative)
    end)

    it_cross_plat("can take absolute paths and make them relative to a given path", function()
      local r = Path:new { root(), "home", "prime" }
      local p = Path:new { "aoeu", "agen.lua" }
      local absolute = r.filename .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative(r.filename)
      assert.are.same(p.filename, relative)
    end)

    it_cross_plat("can take double separator absolute paths and make them relative to the cwd", function()
      local p = Path:new { "lua", "plenary", "path.lua" }
      local absolute = vim.fn.getcwd() .. path.sep .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative()
      assert.are.same(p.filename, relative)
    end)

    it_cross_plat("can take double separator absolute paths and make them relative to a given path", function()
      local r = Path:new { root(), "home", "prime" }
      local p = Path:new { "aoeu", "agen.lua" }
      local absolute = r.filename .. path.sep .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative(r.filename)
      assert.are.same(p.filename, relative)
    end)

    it_cross_plat("can take absolute paths and make them relative to a given path with trailing separator", function()
      local r = Path:new { root(), "home", "prime" }
      local p = Path:new { "aoeu", "agen.lua" }
      local absolute = r.filename .. path.sep .. p.filename
      local relative = Path:new(absolute):make_relative(r.filename .. path.sep)
      assert.are.same(p.filename, relative)
    end)

    it_cross_plat("can take absolute paths and make them relative to the root directory", function()
      local p = Path:new { root(), "prime", "aoeu", "agen.lua" }
      local relative = Path:new(p:absolute()):make_relative(root())
      assert.are.same((p.filename:gsub("^" .. root(), "")), relative)
    end)

    it_cross_plat("can take absolute paths and make them relative to themselves", function()
      local p = Path:new { root(), "home", "prime", "aoeu", "agen.lua" }
      local relative = Path:new(p.filename):make_relative(p.filename)
      assert.are.same(".", relative)
    end)

    it_cross_plat("should fail to make relative a path to somewhere not in the subpath", function()
      assert.has_error(function()
        _ = Path:new({ "tmp", "foo_bar", "fileb.lua" }):make_relative(Path:new { "tmp", "foo" })
      end)
    end)

    it_cross_plat("can walk upwards out of current subpath", function()
      local p = Path:new { "foo", "bar", "baz" }
      local cwd = Path:new { "foo", "foo_inner" }
      local expect = Path:new { "..", "bar", "baz" }
      assert.are.same(expect.filename, p:make_relative(cwd, true))
    end)
  end)

  describe(":shorten", function()
    it_cross_plat("can shorten a path", function()
      local long_path = "this/is/a/long/path"
      local short_path = Path:new(long_path):shorten()
      assert.are.same(short_path, plat_path "t/i/a/l/path")
    end)

    it_cross_plat("can shorten a path's components to a given length", function()
      local long_path = "this/is/a/long/path"
      local short_path = Path:new(long_path):shorten(2)
      assert.are.same(short_path, plat_path "th/is/a/lo/path")

      -- without the leading /
      long_path = "this/is/a/long/path"
      short_path = Path:new(long_path):shorten(3)
      assert.are.same(short_path, plat_path "thi/is/a/lon/path")

      -- where len is greater than the length of the final component
      long_path = "this/is/an/extremely/long/path"
      short_path = Path:new(long_path):shorten(5)
      assert.are.same(short_path, plat_path "this/is/an/extre/long/path")
    end)

    it_cross_plat("can shorten a path's components when excluding parts", function()
      local long_path = "this/is/a/long/path"
      local short_path = Path:new(long_path):shorten(nil, { 1, -1 })
      assert.are.same(short_path, plat_path "this/i/a/l/path")

      -- without the leading /
      long_path = "this/is/a/long/path"
      short_path = Path:new(long_path):shorten(nil, { 1, -1 })
      assert.are.same(short_path, plat_path "this/i/a/l/path")

      -- where excluding positions greater than the number of parts
      long_path = "this/is/an/extremely/long/path"
      short_path = Path:new(long_path):shorten(nil, { 2, 4, 6, 8 })
      assert.are.same(short_path, plat_path "t/is/a/extremely/l/path")

      -- where excluding positions less than the negation of the number of parts
      long_path = "this/is/an/extremely/long/path"
      short_path = Path:new(long_path):shorten(nil, { -2, -4, -6, -8 })
      assert.are.same(short_path, plat_path "this/i/an/e/long/p")
    end)

    it_cross_plat("can shorten a path's components to a given length and exclude positions", function()
      local long_path = "this/is/a/long/path"
      local short_path = Path:new(long_path):shorten(2, { 1, -1 })
      assert.are.same(short_path, plat_path "this/is/a/lo/path")

      long_path = "this/is/a/long/path"
      short_path = Path:new(long_path):shorten(3, { 2, -2 })
      assert.are.same(short_path, plat_path "thi/is/a/long/pat")

      long_path = "this/is/an/extremely/long/path"
      short_path = Path:new(long_path):shorten(5, { 3, -3 })
      assert.are.same(short_path, plat_path "this/is/an/extremely/long/path")
    end)
  end)

  local function assert_permission(expect, actual)
    if iswin then
      return
    end
    assert.equal(expect, actual)
  end

  describe("mkdir / rmdir", function()
    it_cross_plat("can create and delete directories", function()
      local p = Path:new "_dir_not_exist"

      p:rmdir()
      assert.is_false(p:exists())

      p:mkdir()
      assert.is_true(p:exists())
      assert.is_true(p:is_dir())
      assert_permission(0777, p:permission())

      p:rmdir()
      assert.is_false(p:exists())
    end)

    it_cross_plat("fails when exists_ok is false", function()
      local p = Path:new "lua"
      assert.has_error(function()
        p:mkdir { exists_ok = false }
      end)
    end)

    it_cross_plat("fails when parents is not passed", function()
      local p = Path:new("impossible", "dir")
      assert.has_error(function()
        p:mkdir { parents = false }
      end)
      assert.is_false(p:exists())
    end)

    it_cross_plat("can create nested directories", function()
      local p = Path:new("impossible", "dir")
      assert.has_no_error(function()
        p:mkdir { parents = true }
      end)
      assert.is_true(p:exists())

      p:rmdir()
      Path:new("impossible"):rmdir()
      assert.is_false(p:exists())
      assert.is_false(Path:new("impossible"):exists())
    end)

    it_cross_plat("can set different modes", function()
      local p = Path:new "_dir_not_exist"
      assert.has_no_error(function()
        p:mkdir { mode = 0755 }
      end)
      assert_permission(0755, p:permission())

      p:rmdir()
      assert.is_false(p:exists())
    end)
  end)

  describe("touch/rm", function()
    it("can create and delete new files", function()
      local p = Path:new "test_file.lua"
      assert(pcall(p.touch, p))
      assert(p:exists())

      p:rm()
      assert(not p:exists())
    end)

    it("does not effect already created files but updates last access", function()
      local p = Path:new "README.md"
      local last_atime = p:stat().atime.sec
      local last_mtime = p:stat().mtime.sec

      local lines = p:readlines()

      assert(pcall(p.touch, p))
      print(p:stat().atime.sec > last_atime)
      print(p:stat().mtime.sec > last_mtime)
      assert(p:exists())

      assert.are.same(lines, p:readlines())
    end)

    it("does not create dirs if nested in none existing dirs and parents not set", function()
      local p = Path:new { "nested", "nested2", "test_file.lua" }
      assert(not pcall(p.touch, p, { parents = false }))
      assert(not p:exists())
    end)

    it("does create dirs if nested in none existing dirs", function()
      local p1 = Path:new { "nested", "nested2", "test_file.lua" }
      local p2 = Path:new { "nested", "asdf", ".hidden" }
      local d1 = Path:new { "nested", "dir", ".hidden" }
      assert(pcall(p1.touch, p1, { parents = true }))
      assert(pcall(p2.touch, p2, { parents = true }))
      assert(pcall(d1.mkdir, d1, { parents = true }))
      assert(p1:exists())
      assert(p2:exists())
      assert(d1:exists())

      Path:new({ "nested" }):rm { recursive = true }
      assert(not p1:exists())
      assert(not p2:exists())
      assert(not d1:exists())
      assert(not Path:new({ "nested" }):exists())
    end)
  end)

  describe("parents", function()
    it_cross_plat("should extract the ancestors of the path", function()
      local p = Path:new(vim.fn.getcwd())
      local parents = p:parents()
      assert(compat.islist(parents))
      for _, parent in pairs(parents) do
        assert.are.same(type(parent), "string")
      end
    end)

    it_cross_plat("should return itself if it corresponds to path.root", function()
      local p = Path:new(Path.path.root(vim.fn.getcwd()))
      assert.are.same(p:absolute(), p:parent():absolute())
      -- assert.are.same(p, p:parent())
    end)
  end)
end)
