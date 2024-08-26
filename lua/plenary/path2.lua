--- NOTES:
--- Rework on plenary.Path with a focus on better cross-platform support
--- including 'shellslash' support.
--- Effort to improve performance made (notably `:absolue` ~2x faster).
---
--- Some finiky behaviors ironed out
--- eg. `:normalize`
--- TODO: demonstrate
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

--- TODO: rework `_filename` according to `_format_parsed_parts`

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
---@field home string home directory path
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
  home = vim.fn.getcwd(), -- respects shellslash unlike vim.uv.cwd()
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
      local _, root, _ = _WindowsPath:split_root(base)
      return root
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
---@field drv string drive name, eg. 'C:' (only for Windows)
---@field root string root path (excludes drive name)
---@field relparts string[] path separator separated relative path parts
---
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
  drv = self.drv ~= "" and self.drv:gsub(self._flavor.sep, path.sep) or ""

  if self._flavor.has_drv and drv == "" then
    root = ""
  else
    root = vim.F.if_nil(root, self.root)
    root = self.root ~= "" and path.sep:rep(#self.root) or ""
  end

  relparts = vim.F.if_nil(relparts, self.relparts)
  local relpath = table.concat(relparts, path.sep)

  return drv .. root .. relpath
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
    -- resolving/normalizing the path anyways for reasons of compat with old Path
    local p = uv.fs_realpath(self:_filename()) or Path:new({ self.cwd, self }):absolute()
    if self.path.isshellslash then
      self._absolute = p:gsub("\\", path.sep)
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

---@return string[] # a list of the path's logical parents
function Path:parents()
  local res = {}
  local abs = self:absolute()

  return res
end

--- makes a path relative to another (by default the cwd).
--- if path is already a relative path
---@param to string|plenary.Path2? absolute path to make relative to (default: cwd)
---@return string
function Path:make_relative(to)
  to = vim.F.if_nil(to, self.cwd)
  if type(to) == "string" then
    to = Path:new(to)
  end

  if self:is_absolute() then
    local to_abs = to:absolute()

    if to_abs == self:absolute() then
      return "."
    else
      -- TODO
    end
  else
  end

  -- SEE: `Path.relative_to` implementation (3.12) specifically `walk_up` param

  local matches = true
  for i = 1, #to.relparts do
    if to.relparts[i] ~= self.relparts[i] then
      matches = false
      break
    end
  end

  if matches then
    return "."
  end

  -- /home/jt/foo/bar/baz
  -- /home/jt
end


return Path
