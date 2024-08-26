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
        { "foo/bar/", "foo/bar" },
        { { readme_path }, readme_path },
        { { readme_path, license_path }, license_path }, -- takes only the last abs path
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
        local drive = Path:new(vim.loop.cwd()).drv
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

  -- describe(":make_relative", function()
  --   local root = iswin and "c:\\" or "/"
  --   it_cross_plat("can take absolute paths and make them relative to the cwd", function()
  --     local p = Path:new { "lua", "plenary", "path.lua" }
  --     local absolute = vim.loop.cwd() .. path.sep .. p.filename
  --     local relative = Path:new(absolute):make_relative()
  --     assert.are.same(p.filename, relative)
  --   end)

  --   it_cross_plat("can take absolute paths and make them relative to a given path", function()
  --     local r = Path:new { root, "home", "prime" }
  --     local p = Path:new { "aoeu", "agen.lua" }
  --     local absolute = r.filename .. path.sep .. p.filename
  --     local relative = Path:new(absolute):make_relative(r.filename)
  --     assert.are.same(relative, p.filename)
  --   end)

  --   it_cross_plat("can take double separator absolute paths and make them relative to the cwd", function()
  --     local p = Path:new { "lua", "plenary", "path.lua" }
  --     local absolute = vim.loop.cwd() .. path.sep .. path.sep .. p.filename
  --     local relative = Path:new(absolute):make_relative()
  --     assert.are.same(relative, p.filename)
  --   end)

  --   it_cross_plat("can take double separator absolute paths and make them relative to a given path", function()
  --     local r = Path:new { root, "home", "prime" }
  --     local p = Path:new { "aoeu", "agen.lua" }
  --     local absolute = r.filename .. path.sep .. path.sep .. p.filename
  --     local relative = Path:new(absolute):make_relative(r.filename)
  --     assert.are.same(relative, p.filename)
  --   end)

  --   it_cross_plat("can take absolute paths and make them relative to a given path with trailing separator", function()
  --     local r = Path:new { root, "home", "prime" }
  --     local p = Path:new { "aoeu", "agen.lua" }
  --     local absolute = r.filename .. path.sep .. p.filename
  --     local relative = Path:new(absolute):make_relative(r.filename .. path.sep)
  --     assert.are.same(relative, p.filename)
  --   end)

  --   it_cross_plat("can take absolute paths and make them relative to the root directory", function()
  --     local p = Path:new { "home", "prime", "aoeu", "agen.lua" }
  --     local absolute = root .. p.filename
  --     local relative = Path:new(absolute):make_relative(root)
  --     assert.are.same(relative, p.filename)
  --   end)

  --   it_cross_plat("can take absolute paths and make them relative to themselves", function()
  --     local p = Path:new { root, "home", "prime", "aoeu", "agen.lua" }
  --     local relative = Path:new(p.filename):make_relative(p.filename)
  --     assert.are.same(relative, ".")
  --   end)

  --   it_cross_plat("should not truncate if path separator is not present after cwd", function()
  --     local cwd = "tmp" .. path.sep .. "foo"
  --     local p = Path:new { "tmp", "foo_bar", "fileb.lua" }
  --     local relative = Path:new(p.filename):make_relative(cwd)
  --     assert.are.same(p.filename, relative)
  --   end)

  --   it_cross_plat("should not truncate if path separator is not present after cwd and cwd ends in path sep", function()
  --     local cwd = "tmp" .. path.sep .. "foo" .. path.sep
  --     local p = Path:new { "tmp", "foo_bar", "fileb.lua" }
  --     local relative = Path:new(p.filename):make_relative(cwd)
  --     assert.are.same(p.filename, relative)
  --   end)
  -- end)
end)
