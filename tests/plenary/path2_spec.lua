local Path = require "plenary.path2"
local path = Path.path
local compat = require "plenary.compat"
local uv = vim.loop
local iswin = uv.os_uname().sysname == "Windows_NT"

local hasshellslash = vim.fn.exists "+shellslash" == 1

---@param bool boolean
local function set_shellslash(bool)
  if hasshellslash then
    vim.o.shellslash = bool
  end
end

local function it_win(name, test_fn)
  if not iswin then
    return
  end

  if not hasshellslash then
    it(name, test_fn)
  else
    local orig = vim.o.shellslash
    vim.o.shellslash = true
    it(name .. " (shellslash)", test_fn)

    vim.o.shellslash = false
    it(name .. " (noshellslash)", test_fn)
    vim.o.shellslash = orig
  end
end

local function it_cross_plat(name, test_fn)
  if not iswin then
    it(name .. " - unix", test_fn)
  else
    it_win(name .. " - windows", test_fn)
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

local function root()
  if not iswin then
    return "/"
  end
  if hasshellslash and vim.o.shellslash then
    return "C:/"
  end
  return "C:\\"
end

-- set up mock file with consistent eol regardless of system (git autocrlf settings)
-- simplifies reading tests
local licence_lines = {
  "MIT License",
  "",
  "Copyright (c) 2020 TJ DeVries",
  "",
  "Permission is hereby granted, free of charge, to any person obtaining a copy",
  'of this software and associated documentation files (the "Software"), to deal',
  "in the Software without restriction, including without limitation the rights",
  "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell",
  "copies of the Software, and to permit persons to whom the Software is",
  "furnished to do so, subject to the following conditions:",
  "",
  "The above copyright notice and this permission notice shall be included in all",
  "copies or substantial portions of the Software.",
  "",
  'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR',
  "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,",
  "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE",
  "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER",
  "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,",
  "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE",
  "SOFTWARE.",
  "",
}

local license_str = table.concat(licence_lines, "\n")
local tmp_license = Path:new "TMP_LICENSE"
tmp_license:write(license_str, "w")

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

    it_cross_plat("can walk_up out of current subpath", function()
      local p = Path:new { "foo", "bar", "baz" }
      local cwd = Path:new { "foo", "foo_inner" }
      local expect = Path:new { "..", "bar", "baz" }
      assert.are.same(expect.filename, p:make_relative(cwd, { walk_up = true }))
    end)

    it_cross_plat("can walk_up to root", function()
      local p = Path:new { root(), "foo", "bar", "baz" }
      local cwd = Path:new { root(), "def" }
      local expect = Path:new { "..", "foo", "bar", "baz" }
      assert.are.same(expect.filename, p:make_relative(cwd, { walk_up = true }))
    end)

    it_win("handles drive letters case insensitively", function()
      local p = Path:new { "C:/", "foo", "bar", "baz" }
      local cwd = Path:new { "c:/", "foo" }
      local expect = Path:new { "bar", "baz" }
      assert.are.same(expect.filename, p:make_relative(cwd))
    end)
  end)

  describe("normalize", function()
    it_cross_plat("handles empty path", function()
      local p = Path:new ""
      assert.are.same(".", p:normalize())
    end)

    it_cross_plat("removes middle ..", function()
      local p = Path:new "lua/../lua/say.lua"
      local expect = Path:new { "lua", "say.lua" }
      assert.are.same(expect.filename, p:normalize())
    end)

    it_cross_plat("walk up relative path", function()
      local p = Path:new "async/../../lua/say.lua"
      local expect = Path:new { "..", "lua", "say.lua" }
      assert.are.same(expect.filename, p:normalize())
    end)

    it_cross_plat("handles absolute path", function()
      local p = Path:new { root(), "a", "..", "a", "b" }
      local expect = Path:new { root(), "a", "b" }
      assert.are.same(expect.filename, p:normalize())
    end)

    it_cross_plat("makes relative", function()
      local p = Path:new { path.home, "a", "..", "", "a", "b" }
      local expect = Path:new { "a", "b" }
      assert.are.same(expect.filename, p:normalize(path.home))
    end)

    it_cross_plat("make relative walk_up", function()
      local p = Path:new { path.home, "a", "..", "", "a", "b" }
      local cwd = Path:new { path.home, "c" }
      local expect = Path:new { "..", "a", "b" }
      assert.are.same(expect.filename, p:normalize(cwd, { walk_up = true }))
    end)

    it_win("windows drive relative paths", function()
      local p = Path:new { "C:", "a", "..", "", "a", "b" }
      local expect = Path:new { "C:", "a", "b" }
      assert.are.same(expect.filename, p:normalize())
    end)

    it_cross_plat("ignores bad make_relative", function()
      local p = Path:new "foobar"
      assert.are.same(p.filename, p:normalize(path.home))
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

  describe("mkdir / rmdir", function()
    after_each(function()
      uv.fs_rmdir "_dir_not_exist"
      uv.fs_rmdir "impossible/dir"
      uv.fs_rmdir "impossible"
    end)

    it_cross_plat("can create and delete directories", function()
      local p = Path:new "_dir_not_exist"

      p:rmdir()
      assert.is_false(p:exists())

      p:mkdir()
      assert.is_true(p:exists())
      assert.is_true(p:is_dir())

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
  end)

  describe("touch/rm", function()
    after_each(function()
      uv.fs_unlink "test_file.lua"
      uv.fs_unlink "nested/nested2/test_file.lua"
      uv.fs_rmdir "nested/nested2"
      uv.fs_unlink "nested/asdf/.hidden"
      uv.fs_rmdir "nested/asdf"
      uv.fs_unlink "nested/dir/.hidden"
      uv.fs_rmdir "nested/dir"
      uv.fs_rmdir "nested"
    end)

    it_cross_plat("can create and delete new files", function()
      local p = Path:new "test_file.lua"
      assert.not_error(function()
        p:touch()
      end)
      assert.is_true(p:exists())

      assert.not_error(function()
        p:rm()
      end)
      assert.is_true(not p:exists())
    end)

    it_cross_plat("does not effect already created files but updates last access", function()
      local p = Path:new "README.md"
      local lines = p:readlines()

      assert.no_error(function()
        p:touch()
      end)

      assert.is_true(p:exists())
      assert.are.same(lines, p:readlines())
    end)

    it_cross_plat("does not create dirs if nested in none existing dirs and parents not set", function()
      local p = Path:new { "nested", "nested2", "test_file.lua" }
      assert.has_error(function()
        p:touch { parents = false }
      end)
      assert.is_false(p:exists())
    end)

    it_cross_plat("does create dirs if nested in none existing dirs", function()
      local p1 = Path:new { "nested", "nested2", "test_file.lua" }
      local p2 = Path:new { "nested", "asdf", ".hidden" }
      local d1 = Path:new { "nested", "dir", ".hidden" }

      assert.no_error(function()
        p1:touch { parents = true }
      end)
      assert.no_error(function()
        p2:touch { parents = true }
      end)
      assert.no_error(function()
        d1:mkdir { parents = true }
      end)
      assert.is_true(p1:exists())
      assert.is_true(p2:exists())
      assert.is_true(d1:exists())

      assert.no_error(function()
        Path:new({ "nested" }):rm { recursive = true }
      end)
      assert.is_false(p1:exists())
      assert.is_false(p2:exists())
      assert.is_false(d1:exists())
      assert.is_false(Path:new({ "nested" }):exists())
    end)
  end)

  describe("rename", function()
    after_each(function()
      uv.fs_unlink "a_random_filename.lua"
      uv.fs_unlink "not_a_random_filename.lua"
      uv.fs_unlink "some_random_filename.lua"
      uv.fs_unlink "../some_random_filename.lua"
    end)

    it_cross_plat("can rename a file", function()
      local p = Path:new "a_random_filename.lua"
      assert.no_error(function()
        p:touch()
      end)
      assert.is_true(p:exists())

      local new_p
      assert.no_error(function()
        new_p = p:rename "not_a_random_filename.lua"
      end)
      assert.not_nil(new_p)
      assert.are.same("not_a_random_filename.lua", new_p.name)
    end)

    it_cross_plat("can handle an invalid filename", function()
      local p = Path:new "some_random_filename.lua"
      assert.no_error(function()
        p:touch()
      end)
      assert.is_true(p:exists())

      assert.has_error(function()
        p:rename ""
      end)
      assert.has_error(function()
        ---@diagnostic disable-next-line: missing-fields
        p:rename {}
      end)

      assert.are.same("some_random_filename.lua", p.name)
    end)

    it_cross_plat("can move to parent dir", function()
      local p = Path:new "some_random_filename.lua"
      assert.no_error(function()
        p:touch()
      end)
      assert.is_true(p:exists())

      local new_p
      assert.no_error(function()
        new_p = p:rename "../some_random_filename.lua"
      end)
      assert.not_nil(new_p)
      assert.are.same(Path:new("../some_random_filename.lua"):absolute(), new_p:absolute())
    end)

    it_cross_plat("cannot rename to an existing filename", function()
      local p1 = Path:new "a_random_filename.lua"
      local p2 = Path:new "not_a_random_filename.lua"
      assert.no_error(function()
        p1:touch()
        p2:touch()
      end)
      assert.is_true(p1:exists())
      assert.is_true(p2:exists())

      assert.has_error(function()
        p1:rename "not_a_random_filename.lua"
      end)
      assert.are.same(p1.filename, "a_random_filename.lua")
    end)

    it_cross_plat("handles Path as new_name", function()
      local p1 = Path:new "a_random_filename.lua"
      local p2 = Path:new "not_a_random_filename.lua"
      assert.no_error(function()
        p1:touch()
      end)
      assert.is_true(p1:exists())

      local new_p
      assert.no_error(function()
        new_p = p1:rename(p2)
      end)
      assert.not_nil(new_p)
      assert.are.same("not_a_random_filename.lua", new_p.name)
    end)
  end)

  describe("copy", function()
    after_each(function()
      uv.fs_unlink "a_random_filename.rs"
      uv.fs_unlink "not_a_random_filename.rs"
      uv.fs_unlink "some_random_filename.rs"
      uv.fs_unlink "../some_random_filename.rs"
      Path:new("src"):rm { recursive = true }
      Path:new("trg"):rm { recursive = true }
    end)

    it_cross_plat("can copy a file with string destination", function()
      local p1 = Path:new "a_random_filename.rs"
      local p2 = Path:new "not_a_random_filename.rs"
      p1:touch()
      assert.is_true(p1:exists())

      assert.no_error(function()
        p1:copy "not_a_random_filename.rs"
      end)
      assert.is_true(p1:exists())
      assert.are.same(p1.filename, "a_random_filename.rs")
      assert.are.same(p2.filename, "not_a_random_filename.rs")
    end)

    it_cross_plat("can copy a file with Path destination", function()
      local p1 = Path:new "a_random_filename.rs"
      local p2 = Path:new "not_a_random_filename.rs"
      p1:touch()
      assert.is_true(p1:exists())

      assert.no_error(function()
        p1:copy(p2)
      end)
      assert.is_true(p1:exists())
      assert.is_true(p2:exists())
      assert.are.same(p1.filename, "a_random_filename.rs")
      assert.are.same(p2.filename, "not_a_random_filename.rs")
    end)

    it_cross_plat("can copy to parent dir", function()
      local p = Path:new "some_random_filename.rs"
      p:touch()
      assert.is_true(p:exists())

      assert.no_error(function()
        p:copy "../some_random_filename.rs"
      end)
      assert.is_true(p:exists())
    end)

    it_cross_plat("cannot copy an existing file if override false", function()
      local p1 = Path:new "a_random_filename.rs"
      local p2 = Path:new "not_a_random_filename.rs"
      p1:touch()
      p2:touch()
      assert.is_true(p1:exists())
      assert.is_true(p2:exists())

      assert.no_error(function()
        p1:copy("not_a_random_filename.rs", { override = false })
      end)
      assert.are.same(p1.filename, "a_random_filename.rs")
      assert.are.same(p2.filename, "not_a_random_filename.rs")
    end)

    it_cross_plat("fails when copying folders non-recursively", function()
      local src_dir = Path:new "src"
      src_dir:mkdir()
      src_dir:joinpath("file1.lua"):touch()

      local trg_dir = Path:new "trg"
      assert.has_error(function()
        src_dir:copy(trg_dir, { recursive = false })
      end)
    end)

    describe("can copy directories recursively", function()
      local src_dir = Path:new "src"
      local trg_dir = Path:new "trg"

      local files = { "file1", "file2", ".file3" }
      -- set up sub directory paths for creation and testing
      local sub_dirs = { "sub_dir1", "sub_dir1/sub_dir2" }
      local src_dirs = { src_dir }
      local trg_dirs = { trg_dir }
      -- {src, trg}_dirs is a table with all directory levels by {src, trg}
      for _, dir in ipairs(sub_dirs) do
        table.insert(src_dirs, src_dir:joinpath(dir))
        table.insert(trg_dirs, trg_dir:joinpath(dir))
      end

      before_each(function()
        -- generate {file}_{level}.lua on every directory level in src
        -- src
        -- ├── file1_1.lua
        -- ├── file2_1.lua
        -- ├── .file3_1.lua
        -- └── sub_dir1
        --     ├── file1_2.lua
        --     ├── file2_2.lua
        --     ├── .file3_2.lua
        --     └── sub_dir2
        --         ├── file1_3.lua
        --         ├── file2_3.lua
        --         └── .file3_3.lua

        src_dir:mkdir()

        for _, file in ipairs(files) do
          for level, dir in ipairs(src_dirs) do
            local p = dir:joinpath(file .. "_" .. level .. ".lua")
            p:touch { parents = true, exists_ok = true }
            assert.is_true(p:exists())
          end
        end
      end)

      it_cross_plat("hidden=true, override=true", function()
        local success
        assert.no_error(function()
          success = src_dir:copy(trg_dir, { recursive = true, override = true, hidden = true })
        end)

        assert.not_nil(success)
        assert.are.same(9, vim.tbl_count(success))
        for _, res in pairs(success) do
          assert.is_true(res.success)
        end
      end)

      it_cross_plat("hidden=true, override=false", function()
        -- setup
        assert.no_error(function()
          src_dir:copy(trg_dir, { recursive = true, override = true, hidden = true })
        end)

        local success
        assert.no_error(function()
          success = src_dir:copy(trg_dir, { recursive = true, override = false, hidden = true })
        end)

        assert.not_nil(success)
        assert.are.same(9, vim.tbl_count(success))
        for _, res in pairs(success) do
          assert.is_false(res.success)
          assert.not_nil(res.err)
          assert.not_nil(res.err:match "^EEXIST:")
        end
      end)

      it_cross_plat("hidden=false, override=true", function()
        local success
        assert.no_error(function()
          success = src_dir:copy(trg_dir, { recursive = true, override = true, hidden = false })
        end)

        assert.not_nil(success)
        assert.are.same(6, vim.tbl_count(success))
        for _, res in pairs(success) do
          assert.is_true(res.success)
        end
      end)

      it_cross_plat("hidden=false, override=false", function()
        -- setup
        assert.no_error(function()
          src_dir:copy(trg_dir, { recursive = true, override = true, hidden = true })
        end)

        local success
        assert.no_error(function()
          success = src_dir:copy(trg_dir, { recursive = true, override = false, hidden = false })
        end)

        assert.not_nil(success)
        assert.are.same(6, vim.tbl_count(success))
        for _, res in pairs(success) do
          assert.is_false(res.success)
          assert.not_nil(res.err)
          assert.not_nil(res.err:match "^EEXIST:")
        end
      end)
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
      assert.are.same(p, p:parent())
    end)
  end)

  describe("write", function()
    after_each(function()
      uv.fs_unlink "foobar.txt"
    end)

    it_cross_plat("can write string", function()
      local p = Path:new "foobar.txt"
      p:touch()
      assert.no_error(function()
        p:write("hello world", "w")
      end)

      local content = p:read()
      assert.not_nil(content)
      assert.are.same("hello world", content)
    end)

    it_cross_plat("can append string", function()
      local p = Path:new "foobar.txt"
      p:touch()
      assert.no_error(function()
        p:write("hello world", "w")
      end)

      assert.no_error(function()
        p:write("\ngoodbye", "a")
      end)

      local content = p:read()
      assert.not_nil(content)
      assert.are.same("hello world\ngoodbye", content)
    end)

    it_cross_plat("can write string list", function()
      local p = Path:new "foobar.txt"
      p:touch()
      assert.no_error(function()
        p:write({ "hello", " ", "world" }, "w")
      end)

      local content = p:read()
      assert.not_nil(content)
      assert.are.same("hello world", content)
    end)
  end)

  local function diff_str(a, b)
    a = a:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    b = b:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    ---@diagnostic disable-next-line: missing-fields
    return vim.diff(a, b, {})
  end

  describe("head", function()
    after_each(function()
      uv.fs_unlink "foobar.txt"
    end)

    it_cross_plat("should read head of file", function()
      local p = Path:new "TMP_LICENSE"
      local data = p:head()
      local should = [[MIT License

Copyright (c) 2020 TJ DeVries

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:]]

      assert.are.same(should, data, diff_str(should, data))
    end)

    it_cross_plat("should read the first line of file", function()
      local p = Path:new "TMP_LICENSE"
      local data = p:head(1)
      local should = [[MIT License]]
      assert.are.same(should, data, diff_str(should, data))
    end)

    it_cross_plat("should max read whole file", function()
      local p = Path:new "TMP_LICENSE"
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
      assert.are.same(should, data, diff_str(should, data))
    end)

    it_cross_plat("handles unix lf line endings", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\nbar\nbaz"
      p:write(txt, "w")
      local data = p:head()
      assert.are.same(txt, data, diff_str(txt, data))
    end)

    it_cross_plat("handles windows crlf line endings", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\r\nbar\r\nbaz"
      p:write(txt, "w")
      local data = p:head()
      assert.are.same(txt, data, diff_str(txt, data))
    end)

    it_cross_plat("handles mac cr line endings", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\rbar\rbaz"
      p:write(txt, "w")
      local data = p:head()
      assert.are.same(txt, data, diff_str(txt, data))
    end)
  end)

  describe("tail", function()
    after_each(function()
      uv.fs_unlink "foobar.txt"
    end)

    it_cross_plat("should read tail of file", function()
      local p = Path:new "TMP_LICENSE"
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
      assert.are.same(should, data, diff_str(should, data))
    end)

    it_cross_plat("should read the last line of file", function()
      local p = Path:new "TMP_LICENSE"
      local data = p:tail(1)
      local should = [[SOFTWARE.]]
      assert.are.same(should, data, diff_str(should, data))
    end)

    it_cross_plat("should max read whole file", function()
      local p = Path:new "TMP_LICENSE"
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
      assert.are.same(should, data, diff_str(should, data))
    end)

    it_cross_plat("handles unix lf line endings", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\nbar\nbaz"
      p:write(txt, "w")
      local data = p:tail()
      assert.are.same(txt, data, diff_str(txt, data))
    end)

    it_cross_plat("handles windows crlf line endings", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\r\nbar\r\nbaz"
      p:write(txt, "w")
      local data = p:tail()
      assert.are.same(txt, data, diff_str(txt, data))
    end)

    it_cross_plat("handles mac cr line endings", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\rbar\rbaz"
      p:write(txt, "w")
      local data = p:tail()
      assert.are.same(txt, data, diff_str(txt, data))
    end)

    it_cross_plat("handles extra newlines", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\nbar\nbaz\n\n\n"
      local expect = "foo\nbar\nbaz\n\n"
      p:write(txt, "w")
      local data = p:tail()
      assert.are.same(expect, data, diff_str(expect, data))
    end)
  end)

  describe("readbyterange", function()
    after_each(function()
      uv.fs_unlink "foobar.txt"
    end)

    it_cross_plat("should read bytes at given offset", function()
      local p = Path:new "TMP_LICENSE"
      local data = p:readbyterange(13, 10)
      local should = "Copyright "
      assert.are.same(should, data, diff_str(should, data))
    end)

    it_cross_plat("supports negative offset", function()
      local p = Path:new "TMP_LICENSE"
      local data = p:readbyterange(-10, 10)
      local should = "SOFTWARE.\n"
      assert.are.same(should, data, diff_str(should, data))
    end)

    it_cross_plat("handles unix lf line endings", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\nbar\nbaz"
      p:write(txt, "w")
      local data = p:readbyterange(3, 5)
      local expect = "\nbar\n"
      assert.are.same(expect, data, diff_str(expect, data))
    end)

    it_cross_plat("handles windows crlf line endings", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\r\nbar\r\nbaz"
      p:write(txt, "w")
      local data = p:readbyterange(3, 5)
      local expect = "\r\nbar"
      assert.are.same(expect, data, diff_str(expect, data))
    end)

    it_cross_plat("handles mac cr line endings", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "foo\rbar\rbaz"
      p:write(txt, "w")
      local data = p:readbyterange(3, 5)
      local expect = "\rbar\r"
      assert.are.same(expect, data, diff_str(expect, data))
    end)

    it_cross_plat("offset larger than size", function()
      local p = Path:new "foobar.txt"
      p:touch()

      local txt = "hello"
      p:write(txt, "w")
      local data = p:readbyterange(10, 3)
      assert.are.same("", data)
    end)

    it_cross_plat("no offset", function()
      local p = Path:new "TMP_LICENSE"
      local data = p:readbyterange(0, 11)
      local should = "MIT License"
      assert.are.same(should, data, diff_str(should, data))
    end)
  end)

  describe("find_upwards", function()
    it_cross_plat("finds file in current dir", function()
      local p = Path:new "lua/plenary"
      local res = assert(p:find_upwards "busted.lua")
      local expect = Path:new "lua/plenary/busted.lua"
      assert.are.same(expect.filename, res.filename)
    end)

    it_cross_plat("finds file in parent dir", function()
      local p = Path:new "lua/plenary"
      local res = assert(p:find_upwards "say.lua")
      local expect = vim.fn.fnamemodify("lua/say.lua", ":p")
      assert.are.same(expect, res.filename)
    end)

    it_cross_plat("doesn't find file", function()
      local p = Path:new(path.root())
      local res = p:find_upwards "aisohtenaishoetnaishoetnasihoetnashitoen"
      assert.is_nil(res)
    end)
  end)

  describe("expand", function()
    uv.os_setenv("FOOVAR", "foo")
    uv.os_setenv("BARVAR", "bar")

    it_cross_plat("match simple valid $ env vars", function()
      assert.are.same("foo", Path:new("$FOOVAR"):expand())
      assert.are.same("foo$", Path:new("$FOOVAR$"):expand())
      assert.are.same(Path:new("foo/bar/baz").filename, Path:new("$FOOVAR/$BARVAR/baz"):expand())
      assert.are.same(Path:new("foo/bar baz").filename, Path:new("$FOOVAR/$BARVAR baz"):expand())
      assert.are.same(Path:new("foo/$BARVARbaz").filename, Path:new("$FOOVAR/$BARVARbaz"):expand())
    end)

    it_cross_plat("match simple valid $ env vars with braces", function()
      assert.are.same(Path:new("foo/bar/baz").filename, Path:new("${FOOVAR}/${BARVAR}/baz"):expand())
      assert.are.same(Path:new("foo/bar baz").filename, Path:new("${FOOVAR}/${BARVAR} baz"):expand())
    end)

    it_cross_plat("ignore unset $ env var", function()
      local p = Path:new "foo/$NOT_A_REAL_ENV_VAR/baz"
      assert.are.same(p.filename, p:expand())
    end)

    it_cross_plat("ignore empty $", function()
      local p = Path:new "foo/$/bar$baz$"
      assert.are.same(p.filename, p:expand())
    end)

    it_cross_plat("ignore empty ${}", function()
      local p = Path:new "foo/${}/bar${}"
      assert.are.same(p.filename, p:expand())
    end)

    describe("windows", function()
      if not iswin then
        return
      end

      uv.os_setenv("{foovar", "foo1")
      uv.os_setenv("{foovar}", "foo2")

      it_win("match valid %% env var", function()
        assert.are.same(Path:new("foo/bar/baz").filename, Path:new("%foovar%/%BARVAR%/baz"):expand())
        assert.are.same(Path:new("foo1/bar/baz").filename, Path:new("%{foovar%/%BARVAR%/baz"):expand())
        assert.are.same(Path:new("foo2/bar/baz").filename, Path:new("%{foovar}%/%BARVAR%/baz"):expand())
        assert.are.same(Path:new("foo/bar baz").filename, Path:new("%foovar%/%BARVAR% baz"):expand())
      end)

      it_win("empty %%", function()
        local p = Path:new "foo/%%/baz%%"
        assert.are.same(p.filename, p:expand())
      end)

      it_win("match special char env var with ${}", function()
        assert.are.same(Path:new("foo1/bar/baz").filename, Path:new("${{foovar}/%BARVAR%/baz"):expand())
        assert.are.same(Path:new("foo1}/bar/baz").filename, Path:new("${{foovar}}/%BARVAR%/baz"):expand())
      end)

      it_win("ignore unset %% env var", function()
        local p = Path:new "foo/%NOT_A_REAL_ENV_VAR%/baz"
        assert.are.same(p.filename, p:expand())
      end)

      it_win("ignore quoted vars", function()
        local paths = { "'%foovar%'", "'${foovar}'", "'$foovar'" }
        for _, p in ipairs(paths) do
          ---@diagnostic disable-next-line: cast-local-type
          p = Path:new(p)
          assert.are.same(p.filename, p:expand())
        end
      end)
    end)

    it_cross_plat("matches ~", function()
      local p = Path:new "~/hello"
      local expect = Path:new { path.home, "hello" }
      assert.are.same(expect.filename, p:expand())
    end)

    it_cross_plat("does not matches ~user", function()
      local p = Path:new "~otheruser/hello"
      assert.are.same(p.filename, p:expand())
    end)

    uv.os_unsetenv "FOOVAR"
    uv.os_unsetenv "BARVAR"
  end)
end)

tmp_license:rm()
