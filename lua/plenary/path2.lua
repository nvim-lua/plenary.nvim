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
---@field expand fun(self: plenary._Path, parts: string[], sep: string?): string[]
---@field is_relative fun(self: plenary._Path, path: plenary.Path2, to: plenary.Path2): boolean

---@class plenary._WindowsPath : plenary._Path
local _WindowsPath = {
  sep = "\\",
  altsep = "/",
  has_drv = true,
  case_sensitive = false,
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

---@param parts string[]
---@param sep string
---@return string[] new_parts
function _WindowsPath:expand(parts, sep)
  local new_parts = {}

  local function add_expand(sub_parts, var, part, start, end_)
    ---@diagnostic disable-next-line: missing-parameter
    local val = uv.os_getenv(var)
    if val then
      table.insert(sub_parts, (val:gsub("\\", sep)))
    else
      table.insert(sub_parts, part:sub(start, end_))
    end
  end

  for _, part in ipairs(parts) do
    local sub_parts = {}
    local i = 1

    while i <= #part do
      local ch = part:sub(i, i)
      if ch == "'" then -- no expansion inside single quotes
        local end_ = part:find("'", i + 1, true)
        if end_ then
          table.insert(sub_parts, part:sub(i, end_))
          i = end_
        else
          table.insert(sub_parts, ch)
        end
      elseif ch == "%" then
        local end_ = part:find("%", i + 1, true)
        if end_ then
          local var = part:sub(i + 1, end_ - 1)
          add_expand(sub_parts, var, part, i, end_)
          i = end_
        else
          table.insert(sub_parts, ch)
        end
      elseif ch == "$" then
        local nextch = part:sub(i + 1, i + 1)
        if nextch == "$" then
          i = i + 1
          table.insert(sub_parts, ch)
        elseif nextch == "{" then
          local end_ = part:find("}", i + 2, true)
          if end_ then
            local var = part:sub(i + 2, end_ - 1)
            add_expand(sub_parts, var, part, i, end_)
            i = end_
          else
            table.insert(sub_parts, ch)
          end
        else
          local end_ = part:find("[^%w_]", i + 1, false) or #part + 1
          local var = part:sub(i + 1, end_ - 1)
          add_expand(sub_parts, var, part, i, end_ - 1)
          i = end_ - 1
        end
      else
        table.insert(sub_parts, ch)
      end
      i = i + 1
    end

    table.insert(new_parts, table.concat(sub_parts))
  end

  return new_parts
end

---@param path plenary.Path2
---@param to plenary.Path2
---@return boolean
function _WindowsPath:is_relative(path, to)
  if path.anchor:lower() ~= to.anchor:lower() then
    return false
  end

  for i, to_part in ipairs(to.relparts) do
    if to_part:lower() ~= path.relparts[i]:lower() then
      return false
    end
  end
  return true
end

---@class plenary._PosixPath : plenary._Path
local _PosixPath = {
  sep = "/",
  altsep = "",
  has_drv = false,
  case_sensitive = true,
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
    elseif #parts > 1 and parts[#parts]:sub(-1) == self.sep then
      table.insert(parts, p)
    else
      table.insert(parts, self.sep .. p)
    end
  end
  return table.concat(parts)
end

---@param parts string[]
---@return string[] new_parts
function _PosixPath:expand(parts)
  local function add_expand(sub_parts, var, part, start, end_)
    ---@diagnostic disable-next-line: missing-parameter
    local val = uv.os_getenv(var)
    if val then
      table.insert(sub_parts, val)
    else
      table.insert(sub_parts, part:sub(start, end_))
    end
  end

  local new_parts = {}
  for _, part in ipairs(parts) do
    local i = 1
    local sub_parts = {}
    while i <= #part do
      local ch = part:sub(i, i)
      if ch == "$" then
        if part:sub(i + 1, i + 1) == "{" then
          local end_ = part:find("}", i + 2, true)
          if end_ then
            local var = part:sub(i + 2, end_ - 1)
            add_expand(sub_parts, var, part, i, end_)
            i = end_
          else
            table.insert(sub_parts, ch)
          end
        else
          local end_ = part:find("[^%w_]", i + 1, false) or #part + 1
          local var = part:sub(i + 1, end_ - 1)
          add_expand(sub_parts, var, part, i, end_ - 1)
          i = end_ - 1
        end
      else
        table.insert(sub_parts, ch)
      end
      i = i + 1
    end

    table.insert(new_parts, table.concat(sub_parts))
  end

  return new_parts
end

---@param path plenary.Path2
---@param to plenary.Path2
---@return boolean
function _PosixPath:is_relative(path, to)
  if path.root ~= to.root then
    return false
  end

  for i, to_part in ipairs(to.relparts) do
    if to_part ~= path.relparts[i] then
      return false
    end
  end
  return true
end

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
---@param flavor plenary._Path
---@return string drv
---@return string root
---@return string[]
local function parse_parts(parts, flavor)
  local rel
  local drv, root, parsed = "", "", {}

  if #parts == 0 then
    return drv, root, parsed
  end

  local sep = flavor.sep
  local p = flavor:join(unpack(parts))
  drv, root, rel = flavor:split_root(p)

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

local FILE_MODE = 438 -- o666 (aka -rw-rw-rw-)

---@class plenary.Path2
---@field path plenary.path2
---@field private _flavor plenary._Path
---@field private _raw_parts string[]
---@field drv string drive name, eg. 'C:' (only for Windows, empty string for Posix)
---@field root string root path (excludes drive name for Windows)
---@field anchor string drive + root (eg 'C:/' for Windows, just '/' otherwise)
---@field relparts string[] path separator separated relative path parts
---@field sep string path separator (respects 'shellslash' on Windows)
---@field filename string
---@field name string the final path component (eg. "foo/bar/baz.lua" -> "baz.lua")
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

  if k == "name" then
    if #t.relparts > 0 then
      t.name = t.relparts[#t.relparts]
    else
      t.name = ""
    end
    return t.name
  end

  if k == "anchor" then
    t.anchor = t.drv .. t.root
    return t.anchor
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

  if self._flavor ~= other._flavor then
    return false
  end

  if self._flavor.case_sensitive then
    return self.filename == other.filename
  end
  return self.filename:lower() == other.filename:lower()
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
          "Invalid type passed to 'Path:new'. "
            .. "Expects any number of 'string' or 'Path' objects. "
            .. "Got type '%s', shape '%s'",
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
  drv = vim.F.if_nil(drv, self.drv) -- luacheck: ignore
  drv = self.drv ~= "" and self.drv:gsub(self._flavor.sep, self.sep) or ""

  if self._flavor.has_drv and drv == "" then
    root = ""
  else
    root = vim.F.if_nil(root, self.root) -- luacheck: ignore
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

---@param x any
---@return boolean
local function is_path_like(x)
  return type(x) == "string" or Path.is_path(x)
end

local function is_path_like_opt(x)
  return x == nil or is_path_like(x)
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
  local res, err = uv.fs_stat(self:absolute())
  if res == nil then
    error(err)
  end
  return res
end

---@deprecated
function Path:_stat()
  return self:stat()
end

--- Get file status. Like `Path:stat` but if the path points to a symbolic
--- link, returns the symbolic link's information.
--- Will throw error if path doesn't exist.
---@return uv.aliases.fs_stat_table
function Path:lstat()
  local res, err = uv.fs_lstat(self:absolute())
  if res == nil then
    error(err)
  end
  return res
end

---@return integer # numeric mode in octal values
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
--- DOES NOT expand environment variables and home/user constructs (`~` and `~user`).
--- Use `expand` for this.
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

--- get the environment variable expanded filename
--- also expand ~/ but NOT ~user/ constructs
---@return string
function Path:expand()
  local relparts = self._flavor:expand(self.relparts, self.sep)
  local filename = self:_filename(nil, nil, relparts)

  if filename:sub(1, 2) == "~" .. self.sep then
    filename = self.path.home .. filename:sub(2)
  end

  return filename
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
  vim.validate { to = { to, is_path_like } }

  if not Path.is_path(to) then
    to = Path:new(to)
  end
  ---@cast to plenary.Path2

  if to == self then
    return true
  end

  return self._flavor:is_relative(self, to)
end

---@class plenary.Path2.make_relative.Opts
---@field walk_up boolean? walk up to the provided path using '..' (default: `false`)

---@param to string|plenary.Path2?
---@param opts plenary.Path2.make_relative.Opts?
---@return plenary.Path2
function Path:_make_relative(to, opts)
  opts = opts or {}
  vim.validate {
    to = { to, is_path_like_opt },
    walk_up = { opts.walk_up, "b", true },
  }

  opts.walk_up = vim.F.if_nil(opts.walk_up, false)

  if to == nil then
    if not self:is_absolute() then
      return Path:new "."
    end

    to = Path:new(self.cwd)
  elseif type(to) == "string" then
    to = Path:new(to) ---@cast to plenary.Path2
  end

  local abs = self:absolute()
  if abs == to:absolute() then
    return Path:new "."
  end

  if self:is_relative(to) then
    return Path:new((abs:sub(#to:absolute() + 1):gsub("^" .. self.sep, "")))
  end

  if not opts.walk_up then
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
  return Path:new(steps)
end

--- makes a path relative to another (by default the cwd).
--- if path is already a relative path, it will first be turned absolute using
--- the cwd then made relative to the `to` path.
---@param to string|plenary.Path2? path to make relative to (default: cwd)
---@param opts plenary.Path2.make_relative.Opts?
---@return string
function Path:make_relative(to, opts)
  return self:_make_relative(to, opts).filename
end

--- Normalize path, resolving any intermediate ".."
--- eg. `a//b`, `a/./b`, `a/foo/../b` will all become `a/b`
--- Can optionally convert a path to relative to another.
---@param relative_to string|plenary.Path2? path to make relative to, if nil path isn't made relative
---@param opts plenary.Path2.make_relative.Opts?
---@return string
function Path:normalize(relative_to, opts)
  local p
  if relative_to == nil then
    p = self
  else
    local ok
    ok, p = pcall(Path._make_relative, self, relative_to, opts)
    p = ok and assert(p) or self
  end

  local relparts = resolve_dots(p.relparts)
  return p:_filename(nil, nil, relparts)
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
  vim.validate {
    len = { len, "n", true },
    excludes = { excludes, "t", true },
  }

  len = vim.F.if_nil(len, 1)
  excludes = vim.F.if_nil(excludes, { #self.relparts })

  local excl_set = {}
  for _, idx in ipairs(excludes) do
    excl_set[idx] = true
  end

  local new_parts = {}
  for i, part in ipairs(self.relparts) do
    local neg_i = -(#self.relparts + 1) + i
    if #part > len and not excl_set[i] and not excl_set[neg_i] then
      part = part:sub(1, len)
    end
    table.insert(new_parts, part)
  end

  return self:_filename(nil, nil, new_parts)
end

---@class plenary.Path2.mkdir.Opts
--- permission to give to the directory, this is modified by the process's umask
--- (default: `o777`)
--- (currently not implemented in Windows by libuv)
---@field mode integer?
---@field parents boolean? creates parent directories if true and necessary (default: `false`)
---@field exists_ok boolean? ignores error if true and target directory exists (default: `false`)

--- Create directory
---@param opts plenary.Path2.mkdir.Opts?
function Path:mkdir(opts)
  opts = opts or {}
  vim.validate {
    mode = { opts.mode, "n", true },
    parents = { opts.parents, "b", true },
    exists_ok = { opts.exists_ok, "b", true },
  }

  opts.mode = vim.F.if_nil(opts.mode, 511) -- o777
  opts.parents = vim.F.if_nil(opts.parents, false)
  opts.exists_ok = vim.F.if_nil(opts.exists_ok, false)

  local abs_path = self:absolute()

  if not opts.exists_ok and self:exists() then
    error(string.format("FileExistsError: %s", abs_path))
  end

  local ok, err_msg, err_code = uv.fs_mkdir(abs_path, opts.mode)
  if ok then
    return
  end
  if err_code == "EEXIST" then
    return
  end
  if err_code == "ENOENT" then
    if not opts.parents or self.parent == self then
      error(err_msg)
    end
    self:parent():mkdir { mode = opts.mode }
    uv.fs_mkdir(abs_path, opts.mode)
    return
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

---@class plenary.Path2.touch.Opts
---@field mode integer? permissions to give to the file if created (default: `o666`)
--- create parent directories if true and necessary. can optionally take a mode value
--- for the mkdir function (default: `false`)
---@field parents boolean|integer?

--- 'touch' file.
--- If it doesn't exist, creates it including optionally, the parent directories
---@param opts plenary.Path2.touch.Opts?
function Path:touch(opts)
  opts = opts or {}
  vim.validate {
    mode = { opts.mode, "n", true },
    parents = { opts.parents, { "n", "b" }, true },
  }
  opts.mode = vim.F.if_nil(opts.mode, FILE_MODE) -- o666
  opts.parents = vim.F.if_nil(opts.parents, false)

  local abs_path = self:absolute()

  if self:exists() then
    local new_time = os.time()
    uv.fs_utime(abs_path, new_time, new_time)
    return
  end

  if not not opts.parents then
    local mode = type(opts.parents) == "number" and opts.parents or nil ---@cast mode number?
    self:parent():mkdir { mode = mode, parents = true, exists_ok = true }
  end

  local fd, err = uv.fs_open(self:absolute(), "w", opts.mode)
  if fd == nil then
    error(err)
  end

  local ok
  ok, err = uv.fs_close(fd)
  if not ok then
    error(err)
  end
end

---@class plenary.Path2.rm.Opts
---@field recursive boolean? remove directories and their content recursively (defaul: `false`)

--- rm file or optional recursively remove directories and their content recursively
---@param opts plenary.Path2.rm.Opts?
function Path:rm(opts)
  opts = opts or {}
  vim.validate { recursive = { opts.recursive, "b", true } }
  opts.recursive = vim.F.if_nil(opts.recursive, false)

  if not opts.recursive or not self:is_dir() then
    local ok, err, code = uv.fs_unlink(self:absolute())
    if ok or code == "ENOENT" then
      return
    end
    if self:is_dir() then
      error(string.format("Cannnot rm director '%s'.", self:absolute()))
    end
    error(err)
  end

  for p, dirs, files in self:walk(false) do
    for _, file in ipairs(files) do
      local _, err, code = uv.fs_unlink((p / file):absolute())
      if err and code ~= "ENOENT" then
        error(err)
      end
    end

    for _, dir in ipairs(dirs) do
      local _, err, code = uv.fs_rmdir((p / dir):absolute())
      if err and code ~= "ENOENT" then
        error(err)
      end
    end
  end

  self:rmdir()
end

---@param new_name string|plenary.Path2 destination path
---@return plenary.Path2
function Path:rename(new_name)
  vim.validate { new_name = { new_name, is_path_like } }

  if not new_name or new_name == "" then
    error "Please provide the new name!"
  end

  local new_path = self:parent() / new_name ---@type plenary.Path2

  if new_path:exists() then
    error "File or directory already exists!"
  end

  local _, err = uv.fs_rename(self:absolute(), new_path:absolute())
  if err ~= nil then
    error(err)
  end
  return new_path
end

---@class plenary.Path2.copy.Opts
---@field recursive boolean? whether to copy folders recursively (default: `false`)
---@field override boolean? whether to override files (default: `true`)
---@field respect_gitignore boolean? skip folders ignored by all detected `gitignore`s (default: `false`)
---@field hidden boolean? whether to add hidden files in recursively copying folders (default: `true`)
---@field parents boolean? whether to create possibly non-existing parent dirs of `opts.destination` (default: `false`)
---@field exists_ok boolean? whether ok if `opts.destination` exists, if so folders are merged (default: `true`)

---@param destination string|plenary.Path2 target file path to copy to
---@param opts plenary.Path2.copy.Opts?
--- a flat dictionary of destination paths and their copy result.
--- if successful, `{ success = true }`, else `{ success = false, err = "some msg" }`
---@return {[plenary.Path2]: {success:boolean, err: string?}}
function Path:copy(destination, opts)
  opts = opts or {}
  vim.validate {
    destination = { destination, is_path_like },
    recursive = { opts.recursive, "b", true },
    override = { opts.override, "b", true },
  }

  opts.recursive = vim.F.if_nil(opts.recursive, false)
  opts.override = vim.F.if_nil(opts.override, true)

  local dest = self:parent() / destination ---@type plenary.Path2

  local success = {} ---@type {[plenary.Path2]: {success: boolean, err: string?}}

  if not self:is_dir() then
    local ok, err = uv.fs_copyfile(self:absolute(), dest:absolute(), { excl = not opts.override })
    success[dest] = { success = ok or false, err = err }
    return success
  end

  if not opts.recursive then
    error(string.format("Warning: %s was not copied as `recursive=false`", self:absolute()))
  end

  vim.validate {
    respect_gitignore = { opts.respect_gitignore, "b", true },
    hidden = { opts.hidden, "b", true },
    parents = { opts.parents, "b", true },
    exists_ok = { opts.exists_ok, "b", true },
  }

  opts.respect_gitignore = vim.F.if_nil(opts.respect_gitignore, false)
  opts.hidden = vim.F.if_nil(opts.hidden, true)
  opts.parents = vim.F.if_nil(opts.parents, false)
  opts.exists_ok = vim.F.if_nil(opts.exists_ok, true)

  dest:mkdir { parents = opts.parents, exists_ok = opts.exists_ok }

  local scan = require "plenary.scandir"
  local data = scan.scan_dir(self.filename, {
    respect_gitignore = opts.respect_gitignore,
    hidden = opts.hidden,
    depth = 1,
    add_dirs = true,
  })

  for _, entry in ipairs(data) do
    local entry_path = Path:new(entry)
    local new_dest = dest / entry_path.name
    local res = entry_path:copy(new_dest, opts)
    success = vim.tbl_deep_extend("force", success, res)
  end
  return success
end

--- read file synchronously or asynchronously
---@param callback fun(data: string)? callback to use for async version, nil for default
---@return string? data
function Path:read(callback)
  vim.validate { callback = { callback, "f", true } }

  if not self:is_file() then
    error(string.format("'%s' is not a file", self:absolute()))
  end

  if callback == nil then
    return self:_read_sync()
  end
  return self:_read_async(callback)
end

---@private
---@return uv.aliases.fs_stat_table
function Path:_get_readable_stat()
  local stat = self:stat()
  if stat.type ~= "file" then
    error(string.format("Cannot read non-file '%s'.", self:absolute()))
  end
  return stat
end

---@private
---@return string
function Path:_read_sync()
  local stat = self:_get_readable_stat()

  local fd, err = uv.fs_open(self:absolute(), "r", FILE_MODE)
  if fd == nil then
    error(err)
  end

  local data
  data, err = uv.fs_read(fd, stat.size, 0)
  if data == nil then
    error(err)
  end

  _, err = uv.fs_close(fd)
  if err ~= nil then
    error(err)
  end
  return data
end

---@private
---@param callback fun(data: string)
function Path:_read_async(callback)
  uv.fs_open(self:absolute(), "r", FILE_MODE, function(err_open, fd)
    if err_open then
      error(err_open)
    end

    uv.fs_fstat(fd, function(err_stat, stat)
      if err_stat or stat == nil then
        error(err_stat)
      end

      uv.fs_read(fd, stat.size, 0, function(err_read, data)
        if err_read or data == nil then
          error(err_read)
        end
        uv.fs_close(fd, function(err_close)
          if err_close then
            error(err_close)
          end
          callback(data)
        end)
      end)
    end)
  end)
end

--- read lines of a file into a list
---@return string[]
function Path:readlines()
  local data = assert(self:read())
  return vim.split(data, "\r?\n")
end

--- get an iterator for lines text in a file
---@return fun(): string?
function Path:iter_lines()
  local data = assert(self:read())
  return vim.gsplit(data, "\r?\n")
end

--- read the first few lines of a file
---@param lines integer? number of lines to read from the head of the file (default: `10`)
---@return string data
function Path:head(lines)
  vim.validate { lines = { lines, "n", true } }

  local stat = self:_get_readable_stat()

  lines = vim.F.if_nil(lines, 10)
  local chunk_size = 256

  local fd, err = uv.fs_open(self:absolute(), "r", FILE_MODE)
  if fd == nil then
    error(err)
  end

  local data = {}
  local read_chunk ---@type string?
  local index, count = 0, 0
  while count < lines and index < stat.size do
    read_chunk, err = uv.fs_read(fd, chunk_size, index)
    if read_chunk == nil then
      error(err)
    end

    local i = 1
    while i <= #read_chunk do
      local ch = read_chunk:byte(i)
      if ch == 10 then -- `\n`
        if read_chunk:byte(i - 1) ~= 13 then
          count = count + 1
        end
      elseif ch == 13 then
        count = count + 1
      end

      if count >= lines then
        break
      end

      index = index + 1
      i = i + 1
    end

    table.insert(data, read_chunk:sub(1, i))
  end

  _, err = uv.fs_close(fd)
  if err ~= nil then
    error(err)
  end

  return (table.concat(data):gsub("[\r\n]$", ""))
end

--- read the last few lines of a file
---@param lines integer? number of lines to read from the tail of the file (default: `10`)
---@return string data
function Path:tail(lines)
  vim.validate { lines = { lines, "n", true } }

  local stat = self:_get_readable_stat()

  lines = vim.F.if_nil(lines, 10)
  local chunk_size = 256

  local fd, err = uv.fs_open(self:absolute(), "r", FILE_MODE)
  if fd == nil then
    error(err)
  end

  local data = {}
  local read_chunk ---@type string?
  local index, count = stat.size, -1
  while count < lines and index > 0 do
    local real_index = index - chunk_size
    if real_index < 0 then
      chunk_size = chunk_size + real_index
      real_index = 0
    end

    read_chunk, err = uv.fs_read(fd, chunk_size, real_index)
    if read_chunk == nil then
      error(err)
    end

    local i = #read_chunk
    while i > 0 do
      local ch = read_chunk:byte(i)
      if ch == 13 then
        if read_chunk:byte(i + 1) ~= 10 then
          count = count + 1
        end
      elseif ch == 10 then
        count = count + 1
      end

      if count >= lines then
        break
      end

      index = index - 1
      i = i - 1
    end

    table.insert(data, 1, read_chunk:sub(i + 1, #read_chunk))
  end

  _, err = uv.fs_close(fd)
  if err ~= nil then
    error(err)
  end

  return (table.concat(data):gsub("[\r\n]$", ""))
end

---@param offset integer byte offset from which the file is read, supports negative index
---@param length integer number of bytes to read from the offset
---@return string
function Path:readbyterange(offset, length)
  vim.validate {
    offset = { offset, "n" },
    length = { length, "n" },
  }

  local stat = self:_get_readable_stat()
  local fd, err = uv.fs_open(self:absolute(), "r", FILE_MODE)
  if fd == nil then
    error(err)
  end

  if offset < 0 then
    offset = stat.size + offset
    -- Windows fails if offset is < 0 even though offset is defined as signed
    -- http://docs.libuv.org/en/v1.x/fs.html#c.uv_fs_read
    if offset < 0 then
      offset = 0
    end
  end

  local data = ""
  local read_chunk
  while #data < length do
    read_chunk, err = uv.fs_read(fd, length - #data, offset)
    if read_chunk == nil then
      error(err)
    end
    if #read_chunk == 0 then
      break
    end
    data = data .. read_chunk
    offset = offset + #read_chunk
  end

  _, err = uv.fs_close(fd)
  if err ~= nil then
    error(err)
  end

  return data
end

--- write to file
---@param data string|string[] data to write
---@param flags uv.aliases.fs_access_flags|integer  flag used to open file (eg. "w" or "a")
---@param mode integer? mode used to open file (default: `438`)
---@return number # bytes written
function Path:write(data, flags, mode)
  vim.validate {
    txt = { data, { "s", "t" } },
    flags = { flags, { "s", "n" } },
    mode = { mode, "n", true },
  }

  mode = vim.F.if_nil(mode, FILE_MODE)
  local fd, err = uv.fs_open(self:absolute(), flags, mode)
  if fd == nil then
    error(err)
  end

  local b
  b, err = uv.fs_write(fd, data, -1)
  if b == nil then
    error(err)
  end

  _, err = uv.fs_close(fd)
  if err ~= nil then
    error(err)
  end

  return b
end

--- iterate over contents in the current path recursive
---@param top_down boolean? walk from current path down (default: `true`)
---@return fun(): plenary.Path2?, string[]?, string[]? # iterator which yields (dirpath, dirnames, filenames)
function Path:walk(top_down)
  top_down = vim.F.if_nil(top_down, true)

  local queue = { self } ---@type plenary.Path2[]
  local curr_fs = nil ---@type uv_fs_t?
  local curr_path = nil ---@type plenary.Path2

  local rev_res = {} ---@type [plenary.Path2, string[], string[]]

  return function()
    while #queue > 0 or curr_fs do
      if curr_fs == nil then
        local p = table.remove(queue, 1)
        local fs, err = uv.fs_scandir(p:absolute())

        if fs == nil then
          error(err)
        end
        curr_path = p
        curr_fs = fs
      end

      if curr_fs then
        local dirs = {}
        local files = {}
        while true do
          local name, ty = uv.fs_scandir_next(curr_fs)
          if name == nil then
            curr_fs = nil
            break
          end

          if ty == "directory" then
            table.insert(queue, Path:new { curr_path, name })
            table.insert(dirs, name)
          else
            table.insert(files, name)
          end
        end

        if top_down then
          return curr_path, dirs, files
        else
          table.insert(rev_res, { curr_path, dirs, files })
        end
      end
    end

    if not top_down and #rev_res > 0 then
      local res = table.remove(rev_res)
      return res[1], res[2], res[3]
    end

    return nil
  end
end

--- Search for a filename up from the current path, including the current
--- directory, searching up to the root directory.
--- Returns the `Path` of the first item found.
--- Returns `nil` if filename is not found.
---@param filename string
---@return plenary.Path2?
function Path:find_upwards(filename)
  vim.validate { filename = { filename, "s" } }

  if self:is_dir() then
    local target = self / filename
    if target:exists() then
      return target
    end
  end

  for parent in self:iter_parents() do
    local target = Path:new { parent, filename }
    if target:exists() then
      return target
    end
  end
end

return Path
