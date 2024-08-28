--- NOTES:
--- Rework on plenary.Path with a focus on better cross-platform support
--- including 'shellslash' support.
--- Effort to improve performance made (notably `:absolue` ~2x faster).
---
---
--- BREAKING CHANGES:
--- - `Path.new` no longer supported (think it's more confusing that helpful
---   and not really used as far as I can tell)
---
--- - drop `__concat` metamethod? it was untested, not sure how functional it is
---
--- - `Path` objects are now "read-only", I don't think people were ever doing
---   things like `path.filename = 'foo'` but now explicitly adding some barrier
---   to this. Allows us to compute `filename` from "metadata" parsed once on
---   instantiation.
---
--- - FIX: `Path:make_relative` throws error if you try to make a path relative
---   to another path that is not in the same subpath.
---
---   eg. `Path:new("foo/bar_baz"):make_relative("foo/bar")` => errors as you
---   can't get to "foo/bar_baz" from "foo/bar" without going up in directory.
---   This would previously return "foo/bar_baz" which is wrong.
---
---   Adds an option to walk up path to compensate.
---
---   eg. `Path:new("foo/bar_baz"):make_relative("foo/bar", true)` => returns
---   "../bar_baz"
---
--- - remove `Path:normalize`. It doesn't make any sense. eg. this test case
---   ```lua
---   it("can normalize ~ when file is within home directory (trailing slash)", function()
---     local home = "/home/test/"
---     local p = Path:new { home, "./test_file" }
---     p.path.home = home
---     p._cwd = "/tmp/lua"
---     assert.are.same("~/test_file", p:normalize())
---   end)
---   ```
---   if the idea is to make `/home/test/test_file` relative to `/tmp/lua`, the result
---   should be `../../home/test/test_file`, only then can you substitue the
---   home directory for `~`.
---   So should really be `../../~/test_file`. But using `~` in a relative path
---   like that looks weird to me. And as this function first makes paths
---   relative, you will never get a leading `~` (since `~` literally
---   represents the absolute path of the home directory).
---   To top it off, something like `../../~/test_file` is impossible on Windows.
---   `C:/Users/test/test_file` relative to `C:/Windows/temp` is
---   `../../Users/test/test_file` and there's no home directory absolute path
---   in this.

local bit = require "plenary.bit"
local uv = vim.loop
local iswin = uv.os_uname().sysname == "Windows_NT"
local hasshellslash = vim.fn.exists "+shellslash" == 1

---@class plenary._Path
---@field sep string
---@field altsep string
---@field has_drv boolean
---@field case_sensitive boolean
---@field convert_altsep fun(self: plenary._Path, p:string): string
---@field split_root fun(self: plenary._Path, part:string): string, string, string
---@field join fun(self: plenary._Path, path: string, ...: string): string

---@class plenary._WindowsPath : plenary._Path
local _WindowsPath = {
  sep = "\\",
  altsep = "/",
  has_drv = true,
  case_sensitive = true,
}

setmetatable(_WindowsPath, { __index = _WindowsPath })

---@param p string
---@return string
function _WindowsPath:convert_altsep(p)
  return (p:gsub(self.altsep, self.sep))
end

--- splits path into drive, root, and relative path components
--- split_root('//server/share/') == { '//server/share', '/', '' }
--- split_root('C:/Users/Barney') == { 'C:', '/', 'Users/Barney' }
--- split_root('C:///spam///ham') == { 'C:', '/', '//spam///ham' }
--- split_root('Windows/notepad') == { '', '', 'Windows/notepad' }
--- https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats
---@param p string path with only `\` separators
---@return string drv
---@return string root
---@return string relpath
function _WindowsPath:split_root(p)
  p = self:convert_altsep(p)

  local unc_prefix = "\\\\?\\UNC\\"
  local first, second = p:sub(1, 1), p:sub(2, 2)

  if first == self.sep then
    if second == self.sep then
      -- UNC drives, e.g. \\server\share or \\?\UNC\server\share
      -- Device drives, e.g. \\.\device or \\?\device
      local start = p:sub(1, 8):upper() == unc_prefix and 8 or 2
      local index = p:find(self.sep, start)
      if index == nil then
        return p, "", "" -- paths only has drive info
      end

      local index2 = p:find(self.sep, index + 1)
      if index2 == nil then
        return p, "", "" -- still paths only has drive info
      end
      return p:sub(1, index2 - 1), self.sep, p:sub(index2 + 1)
    else
      -- Relative path with root, eg. \Windows
      return "", p:sub(1, 1), p:sub(2)
    end
  elseif p:sub(2, 2) == ":" then
    if p:sub(3, 3) == self.sep then
      -- absolute path with drive, eg. C:\Windows
      return p:sub(1, 2), self.sep, p:sub(3)
    else
      -- relative path with drive, eg. C:Windows
      return p:sub(1, 2), "", p:sub(3)
    end
  else
    -- relative path, eg. Windows
    return "", "", p
  end
end

---@param path string
---@param ... string
---@return string
function _WindowsPath:join(path, ...)
  local paths = { ... }

  local result_drive, result_root, result_path = self:split_root(path)
  local parts = {}

  if result_path ~= "" then
    table.insert(parts, result_path)
  end

  for _, p in ipairs(paths) do
    p = self:convert_altsep(p)
    local p_drive, p_root, p_path = self:split_root(p)

    if p_root ~= "" then
      -- second path is absolute
      if p_drive ~= "" or result_drive == "" then
        result_drive = p_drive
      end
      result_root = p_root
      parts = { p_path }
    elseif p_drive ~= "" and p_drive:lower() ~= result_drive:lower() then
      -- drive letter is case insensitive
      -- here they don't match => ignore first path, later paths take precedence
      result_drive, result_root, parts = p_drive, p_root, { p_path }
    else
      if p_drive ~= "" then
        result_drive = p_drive
      end

      if #parts > 0 and parts[#parts]:sub(-1) ~= self.sep then
        table.insert(parts, self.sep)
      end

      table.insert(parts, p_path)
    end
  end

  local drv_last_ch = result_drive:sub(-1)
  if
    result_path ~= ""
    and result_root == ""
    and result_drive ~= ""
    and not (drv_last_ch == self.sep or drv_last_ch == ":")
  then
    return result_drive .. self.sep .. table.concat(parts)
  end

  return result_drive .. result_root .. table.concat(parts)
end

---@class plenary._PosixPath : plenary._Path
local _PosixPath = {
  sep = "/",
  altsep = "",
  has_drv = false,
  case_sensitive = false,
}
setmetatable(_PosixPath, { __index = _PosixPath })

---@param p string
---@return string
function _PosixPath:convert_altsep(p)
  return p
end

---@param part string path
---@return string drv
---@return string root
---@return string relpath
function _PosixPath:split_root(part)
  if part:sub(1, 1) == self.sep then
    return "", self.sep, part:sub(2)
  end
  return "", "", part
end

---@param path string
---@param ... string
---@return string
function _PosixPath:join(path, ...)
  local paths = { ... }
  local parts = {}

  if path ~= "" then
    table.insert(parts, path)
  end

  for _, p in ipairs(paths) do
    if p:sub(1, 1) == self.sep then
      parts = { p } -- is absolute, ignore previous path, later paths take precedence
    elseif path == "" or path:sub(-1) == self.sep then
      table.insert(parts, p)
    else
      table.insert(parts, self.sep .. p)
    end
  end
  return table.concat(parts)
end

--[[

        for b in map(os.fspath, p):
            if b.startswith(sep):
                path = b
            elif not path or path.endswith(sep):
                path += b
            else:
                path += sep + b
]]

local S_IF = {
  -- S_IFDIR  = 0o040000  # directory
  DIR = 0x4000,
  -- S_IFREG  = 0o100000  # regular file
  REG = 0x8000,
}

---@class plenary.path2
---@field home string? home directory path
---@field sep string OS path separator respecting 'shellslash'
---@field isshellslash boolean whether shellslash is on (always false on unix systems)
---
--- get the root directory path.
--- On Windows, this is determined from the current working directory in order
--- to capture the current disk name. But can be calculated from another path
--- using the optional `base` parameter.
---@field root fun(base: string?):string
---@field S_IF { DIR: integer, REG: integer } stat filetype bitmask
local path = setmetatable({
  S_IF = S_IF,
}, {
  __index = function(t, k)
    local raw = rawget(t, k)
    if raw then
      return raw
    end

    if k == "isshellslash" then
      return (hasshellslash and vim.o.shellslash)
    end

    if k == "sep" then
      if not iswin then
        t.sep = "/"
        return t.sep
      end

      return t.isshellslash and "/" or "\\"
    end

    if k == "home" then
      if not iswin then
        t.home = uv.os_homedir()
        return t.home
      end

      local home = uv.os_homedir()
      if home == nil then
        return home
      end
      return (home:gsub("\\", t.sep))
    end
  end,
})

path.root = (function()
  if not iswin then
    return function()
      return "/"
    end
  else
    return function(base)
      base = base or path.home
      local drv, root, _ = _WindowsPath:split_root(base)
      return ((drv .. root):gsub("\\", path.sep))
    end
  end
end)()

---@param parts string[]
---@param _flavor plenary._Path
---@return string drv
---@return string root
---@return string[]
local function parse_parts(parts, _flavor)
  local drv, root, rel, parsed = "", "", "", {}

  if #parts == 0 then
    return drv, root, parsed
  end

  local sep = _flavor.sep
  local p = _flavor:join(unpack(parts))
  drv, root, rel = _flavor:split_root(p)

  if root == "" and drv:sub(1, 1) == sep and drv:sub(-1) ~= sep then
    local drv_parts = vim.split(drv, sep)
    if #drv_parts == 4 and not (drv_parts[3] == "?" or drv_parts[3] == ".") then
      -- e.g. //server/share
      root = sep
    elseif #drv_parts == 6 then
      -- e.g. //?/unc/server/share
      root = sep
    end
  end

  for part in vim.gsplit(rel, sep) do
    if part ~= "" and part ~= "." then
      table.insert(parsed, part)
    end
  end

  return drv, root, parsed
end

---@class plenary.Path2
---@field path plenary.path2
---@field private _flavor plenary._Path
---@field private _raw_parts string[]
---@field drv string drive name, eg. 'C:' (only for Windows, empty string for Posix)
---@field root string root path (excludes drive name for Windows)
---@field relparts string[] path separator separated relative path parts
---@field sep string path separator (respects 'shellslash' on Windows)
---@field filename string
---@field cwd string
---@field private _absolute string? lazy eval'ed fully resolved absolute path
local Path = { path = path }

---@param t plenary.Path2
---@param k string
Path.__index = function(t, k)
  local raw = rawget(Path, k)
  if raw then
    return raw
  end

  if k == "drv" or k == "root" or k == "relparts" then
    t.drv, t.root, t.relparts = parse_parts(t._raw_parts, t._flavor)
    return rawget(t, k)
  end

  if k == "filename" then
    t.filename = t:_filename()
    return t.filename
  end

  if k == "sep" then
    return path.sep
  end

  if k == "cwd" then
    t.cwd = vim.fn.getcwd()
    return t.cwd
  end
end

---@param self plenary.Path2
---@param other string|plenary.Path2
---@return plenary.Path2
Path.__div = function(self, other)
  assert(Path.is_path(self))
  assert(Path.is_path(other) or type(other) == "string")

  return self:joinpath(other)
end

---@param self plenary.Path2
---@return string
Path.__tostring = function(self)
  return self.filename
end

---@param self plenary.Path2
---@param other string|plenary.Path2
---@return boolean
Path.__eq = function(self, other)
  assert(Path.is_path(self))

  local oth_type_str = type(other) == "string"
  assert(Path.is_path(other) or oth_type_str)

  if oth_type_str then
    other = Path:new(other)
  end
  ---@cast other plenary.Path2

  return self:absolute() == other:absolute()
end

local _readonly_mt = {
  __index = function(t, k)
    return t.__inner[k]
  end,
  __newindex = function(t, k, val)
    if k == "_absolute" then
      t.__inner[k] = val
      return
    end
    error "'Path' object is read-only"
  end,
    -- stylua: ignore start
    __div = function(t, other) return Path.__div(t, other) end,
    __tostring = function(t) return Path.__tostring(t) end,
    __eq = function(t, other) return Path.__eq(t, other) end, -- this never gets called
    __metatable = Path,
  -- stylua: ignore end
}

---@alias plenary.Path2Args string|plenary.Path2|(string|plenary.Path2)[]

---@param ... plenary.Path2Args
---@return plenary.Path2
function Path:new(...)
  local args = { ... }

  if #args == 1 then
    local arg = args[1]
    if type(arg) == "table" and not self.is_path(arg) then
      args = arg
    elseif type(arg) ~= "string" and not self.is_path(arg) then
      error(
        string.format(
          "Invalid type passed to 'Path:new'. Expects any number of 'string' or 'Path' objects. Got type '%s', shape '%s'",
          type(arg),
          vim.inspect(arg)
        )
      )
    end
  end

  local raw_parts = {}
  for _, a in ipairs(args) do
    if self.is_path(a) then
      vim.list_extend(raw_parts, a._raw_parts)
    else
      if a ~= "" then
        table.insert(raw_parts, a)
      end
    end
  end

  local _flavor = iswin and _WindowsPath or _PosixPath

  local proxy = { _flavor = _flavor, _raw_parts = raw_parts }
  setmetatable(proxy, Path)

  local obj = { __inner = proxy }
  setmetatable(obj, _readonly_mt)

  return obj
end

---@private
---@param drv string?
---@param root string?
---@param relparts string[]?
---@return string
function Path:_filename(drv, root, relparts)
  drv = vim.F.if_nil(drv, self.drv)
  drv = self.drv ~= "" and self.drv:gsub(self._flavor.sep, self.sep) or ""

  if self._flavor.has_drv and drv == "" then
    root = ""
  else
    root = vim.F.if_nil(root, self.root)
    root = self.root ~= "" and self.sep:rep(#self.root) or ""
  end

  relparts = vim.F.if_nil(relparts, self.relparts)
  local relpath = table.concat(relparts, self.sep)
  local res = drv .. root .. relpath

  if res ~= "" then
    return res
  end
  return "."
end

---@param x any
---@return boolean
function Path.is_path(x)
  return getmetatable(x) == Path
end

---@return boolean
function Path:is_absolute()
  if self.root == "" then
    return false
  end

  return not self._flavor.has_drv or self.drv ~= ""
end

--- Get file status.
--- Will throw error if path doesn't exist.
---@return uv.aliases.fs_stat_table
function Path:stat()
  local res, _, err_msg = uv.fs_stat(self:absolute())
  if res == nil then
    error(err_msg)
  end
  return res
end

--- Get file status. Like `Path:stat` but if the path points to a symbolic
--- link, returns the symbolic link's information.
--- Will throw error if path doesn't exist.
---@return uv.aliases.fs_stat_table
function Path:lstat()
  local res, _, err_msg = uv.fs_lstat(self:absolute())
  if res == nil then
    error(err_msg)
  end
  return res
end

---@return integer
function Path:permission()
  local stat = self:stat()
  local perm = bit.band(stat.mode, 0x1FF)
  local owner = bit.rshift(perm, 6)
  local group = bit.rshift(perm, 3) % 8
  local user = perm % 8

  return owner * 100 + group * 10 + user
end

---@return boolean
function Path:exists()
  local stat = uv.fs_stat(self:absolute())
  return stat ~= nil and not vim.tbl_isempty(stat)
end

--- if path doesn't exists, returns false
---@return boolean
function Path:is_dir()
  local stat = uv.fs_stat(self:absolute())
  if stat then
    return stat.type == "directory"
  end
  return false
end

--- if path doesn't exists, returns false
---@return boolean
function Path:is_file()
  local stat = uv.fs_stat(self:absolute())
  if stat then
    return stat.type == "file"
  end
  return false
end

---@param relparts string[] path parts
---@return string[]
local function resolve_dots(relparts)
  local new_parts = {}
  for _, part in ipairs(relparts) do
    if part == ".." then
      if #new_parts > 0 and new_parts[#new_parts] ~= ".." then
        table.remove(new_parts)
      elseif #new_parts == 0 then
        table.insert(new_parts, part)
      end
    else
      table.insert(new_parts, part)
    end
  end

  return new_parts
end

--- normalized and resolved absolute path
---
--- if given path doesn't exists and isn't already an absolute path, creates
--- one using the cwd
---
--- respects 'shellslash' on Windows
---@return string
function Path:absolute()
  if self._absolute then
    return self._absolute
  end

  local relparts = resolve_dots(self.relparts)
  if self:is_absolute() then
    self._absolute = self:_filename(nil, nil, relparts)
  else
    -- using fs_realpath over fnamemodify
    -- fs_realpath resolves symlinks whereas fnamemodify doesn't but we're
    -- resolving/normalizing the path anyways for reasons of compat with old
    -- Path
    local p = uv.fs_realpath(self:_filename()) or Path:new({ self.cwd, self }):absolute()
    if self.path.isshellslash then
      self._absolute = p:gsub("\\", self.sep)
    else
      self._absolute = p
    end
  end
  return self._absolute
end

---@param ... plenary.Path2Args
---@return plenary.Path2
function Path:joinpath(...)
  return Path:new { self, ... }
end

---@return plenary.Path2
function Path:parent()
  local parent = self:iter_parents()()
  if parent == nil then
    return Path:new(self.filename)
  end
  return Path:new(parent)
end

--- a list of the path's logical parents.
--- path is made absolute using cwd if relative
---@return string[] # a list of the path's logical parents
function Path:parents()
  local res = {}
  for p in self:iter_parents() do
    table.insert(res, p)
  end
  return res
end

---@return fun(): string? # iterator function
function Path:iter_parents()
  local abs = Path:new(self:absolute())
  local root_part = abs.drv .. abs.root
  root_part = self.path.isshellslash and root_part:gsub("\\", self.sep) or root_part

  local root_sent = #abs.relparts == 0
  return function()
    table.remove(abs.relparts)
    if #abs.relparts < 1 then
      if not root_sent then
        root_sent = true
        return root_part
      end
      return nil
    end
    return root_part .. table.concat(abs.relparts, self.sep)
  end
end

--- return true if the path is relative to another, otherwise false
---@param to plenary.Path2|string path to compare to
---@return boolean
function Path:is_relative(to)
  if not Path.is_path(to) then
    to = Path:new(to)
  end
  ---@cast to plenary.Path2

  if to == self then
    return true
  end

  -- NOTE: could probably be optimized by letting _WindowsPath/_WindowsPath
  -- handle this.

  local to_abs = to:absolute()
  for parent in self:iter_parents() do
    if to_abs == parent then
      return true
    end
  end

  return false
end

--- makes a path relative to another (by default the cwd).
--- if path is already a relative path, it will first be turned absolute using
--- the cwd then made relative to the `to` path.
---@param to string|plenary.Path2? absolute path to make relative to (default: cwd)
---@param walk_up boolean? walk up to the provided path using '..' (default: `false`)
---@return string
function Path:make_relative(to, walk_up)
  -- NOTE: could probably take some shortcuts and avoid some `Path:new` calls
  -- by allowing _WindowsPath/_PosixPath handle this individually.
  -- As always, Windows root complicates things, so generating a new Path often
  -- easier/less error prone than manual string manipulate but at the cost of
  -- perf.
  walk_up = vim.F.if_nil(walk_up, false)

  if to == nil then
    if not self:is_absolute() then
      return "."
    end

    to = Path:new(self.cwd)
  elseif type(to) == "string" then
    to = Path:new(to) ---@cast to plenary.Path2
  end

  local abs = self:absolute()
  if abs == to:absolute() then
    return "."
  end

  if self:is_relative(to) then
    return Path:new(abs:sub(#to:absolute() + 1)).filename
  end

  if not walk_up then
    error(string.format("'%s' is not in the subpath of '%s'", self, to))
  end

  local steps = {}
  local common_path
  for parent in to:iter_parents() do
    table.insert(steps, "..")
    if abs:sub(1, #parent) == parent then
      common_path = parent
      break
    end
  end

  if not common_path then
    error(string.format("'%s' and '%s' have different anchors", self, to))
  end

  local res_path = abs:sub(#common_path + 1):gsub("^" .. self.sep, "")
  table.insert(steps, res_path)
  return Path:new(steps).filename
end

--- Shorten path parts.
--- By default, shortens all part except the last tail part to a length of 1.
--- eg.
--- ```lua
--- local p = Path:new("this/is/a/long/path")
--- p:shorten() -- Output: "t/i/a/l/path"
--- ```
---@param len integer? length to shorthen path parts to (default: `1`)
--- indices of path parts to exclude from being shortened, supports negative index
---@param excludes integer[]?
---@return string
function Path:shorten(len, excludes)
  len = vim.F.if_nil(len, 1)
  excludes = vim.F.if_nil(excludes, { #self.relparts })

  local new_parts = {}

  for i, part in ipairs(self.relparts) do
    local neg_i = -(#self.relparts + 1) + i
    if #part > len and not vim.list_contains(excludes, i) and not vim.list_contains(excludes, neg_i) then
      part = part:sub(1, len)
    end
    table.insert(new_parts, part)
  end

  return self:_filename(nil, nil, new_parts)
end

---@class plenary.Path2.mkdirOpts
---@field mode integer? permission to give to the directory, no umask effect will be applied (default: `o777`)
---@field parents boolean? creates parent directories if true and necessary (default: `false`)
---@field exists_ok boolean? ignores error if true and target directory exists (default: `false`)

--- Create directory
---@param opts plenary.Path2.mkdirOpts?
---@return boolean success
function Path:mkdir(opts)
  opts = opts or {}
  opts.mode = vim.F.if_nil(opts.mode, 511)
  opts.parents = vim.F.if_nil(opts.parents, false)
  opts.exists_ok = vim.F.if_nil(opts.exists_ok, false)

  local abs_path = self:absolute()

  if not opts.exists_ok and self:exists() then
    error(string.format("FileExistsError: %s", abs_path))
  end

  local ok, err_msg, err_code = uv.fs_mkdir(abs_path, opts.mode)
  if ok then
    return true
  end
  if err_code == "EEXIST" then
    return true
  end
  if err_code == "ENOENT" then
    if not opts.parents or self.parent == self then
      error(err_msg)
    end
    self:parent():mkdir { mode = opts.mode }
    uv.fs_mkdir(abs_path, opts.mode)
    return true
  end

  error(err_msg)
end

--- Delete directory
function Path:rmdir()
  if not self:exists() then
    return
  end

  local ok, err_msg = uv.fs_rmdir(self:absolute())
  if not ok then
    error(err_msg)
  end
end

---@class plenary.Path2.touchOpts
---@field mode integer? permissions to give to the file if created (default: `o666`)
--- create parent directories if true and necessary. can optionally take a mode value
--- for the mkdir function (default: `false`)
---@field parents boolean|integer?

--- 'touch' file.
--- If it doesn't exist, creates it including optionally, the parent directories
---@param opts plenary.Path2.touchOpts?
---@return boolean success
function Path:touch(opts)
  opts = opts or {}
  opts.mode = vim.F.if_nil(opts.mode, 438)
  opts.parents = vim.F.if_nil(opts.parents, false)

  local abs_path = self:absolute()

  if self:exists() then
    local new_time = os.time()
    uv.fs_utime(abs_path, new_time, new_time)
    return true
  end

  if not not opts.parents then
    local mode = type(opts.parents) == "number" and opts.parents ---@cast mode number?
    _ = Path:new(self:parent()):mkdir { mode = mode, parents = true }
  end
end

return Path
