--[[
- [x]  path
- [x]  path.home
- [x]  path.sep
- [x]  path.root
- [x]  path.S_IF
  - [ ]  band
  - [ ]  concat_paths
  - [ ]  is_root
  - [ ]  _split_by_separator
  - [ ]  is_uri
  - [ ]  is_absolute
  - [ ]  _normalize_path
  - [ ]  clean
- [x]  Path
- [ ]  check_self
- [x]  Path.__index
- [x]  Path.__div
- [x]  Path.__tostring
- [x]  Path.__concat
- [x]  Path.is_path
- [x]  Path:new
- [x]  Path:_fs_filename
- [x]  Path:_stat
- [x]  Path:_st_mode
- [x]  Path:joinpath
- [x]  Path:absolute
- [x]  Path:exists
- [ ]  Path:expand
- [x]  Path:make_relative
- [ ]  Path:normalize
- [ ]  shorten_len
- [ ]  shorten
- [ ]  Path:shorten
- [ ]  Path:mkdir
- [ ]  Path:rmdir
- [ ]  Path:rename
- [ ]  Path:copy
- [ ]  Path:touch
- [ ]  Path:rm
- [ ]  Path:is_dir
- [x]  Path:is_absolute
- [ ]  Path:_split
  - [ ]  _get_parent
- [ ]  Path:parent
- [ ]  Path:parents
- [ ]  Path:is_file
- [ ]  Path:open
- [ ]  Path:close
- [ ]  Path:write
- [ ]  Path:_read
- [ ]  Path:_read_async
- [ ]  Path:read
- [ ]  Path:head
- [ ]  Path:tail
- [ ]  Path:readlines
- [ ]  Path:iter
- [ ]  Path:readbyterange
-[ ]  Path:find_upwards
]]

local uv = vim.loop

local iswin = uv.os_uname().sysname == "Windows_NT"
local hasshellslash = vim.fn.exists "+shellslash" == 1

local S_IF = {
  -- S_IFDIR  = 0o040000  # directory
  DIR = 0x4000,
  -- S_IFREG  = 0o100000  # regular file
  REG = 0x8000,
}

---@class plenary.path
---@field home string home directory path
---@field sep string OS path separator respecting 'shellslash'
---
--- OS separator for paths returned by libuv functions.
--- Note: libuv will happily take either path separator regardless of 'shellslash'.
---@field private _uv_sep string
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
  _uv_sep = iswin and "\\" or "/",
}, {
  __index = function(t, k)
    local raw = rawget(t, k)
    if raw then
      return raw
    end

    if k == "sep" then
      if not iswin then
        t.sep = "/"
        return t.sep
      end

      return (hasshellslash and vim.o.shellslash) and "/" or "\\"
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
      local disk = base:match "^[%a]:"
      if disk then
        return disk .. path.sep
      end
      return string.rep(path.sep, 2) -- UNC
    end
  end
end)()

--- WARNING: Should really avoid using this. It's more like
--- `maybe_uri_maybe_not`. There are both false positives and false negative
--- edge cases.
---
--- Approximates if a filename is a valid URI by checking if the filename
--- starts with a plausible scheme.
---
--- A valid URI scheme begins with a letter, followed by any number of letters,
--- numbers and `+`, `.`, `-` and ends with a `:`.
---
--- To disambiguate URI schemes from Windows path, we also check up to 2
--- characters after the `:` to make sure it's followed by `//`.
---
--- Two major caveats according to our checks:
--- - a "valid" URI is also a valid unix relative path so any relative unix
---   path that's in the shape of a URI according to our check will be flagged
---   as a URI.
--- - relative Windows paths like `C:Projects/apilibrary/apilibrary.sln` will
---   be caught as a URI.
---
---@param filename string
---@return boolean
local function is_uri(filename)
  local ch = filename:byte(1) or 0

  -- is not alpha?
  if not ((ch >= 97 and ch <= 122) or (ch >= 65 and ch <= 90)) then
    return false
  end

  local scheme_end = 0
  for i = 2, #filename do
    ch = filename:byte(i)
    if
      (ch >= 97 and ch <= 122) -- a-z
      or (ch >= 65 and ch <= 90) -- A-Z
      or (ch >= 48 and ch <= 57) -- 0-9
      or ch == 43 -- `+`
      or ch == 46 -- `.`
      or ch == 45 -- `-`
    then -- luacheck: ignore 542
      -- pass
    elseif ch == 58 then
      scheme_end = i
      break
    else
      return false
    end
  end

  if scheme_end == 0 then
    return false
  end

  local next = filename:byte(scheme_end + 1) or 0
  if next == 0 then
    -- nothing following the scheme
    return false
  elseif next == 92 then -- `\`
    -- could be Windows absolute path but not a uri
    return false
  elseif next == 47 and (filename:byte(scheme_end + 2) or 0) ~= 47 then -- `/`
    -- still could be Windows absolute path using `/` seps but not a uri
    return false
  end
  return true
end

--- Split a Windows path into a prefix and a body, such that the body can be processed like a POSIX
--- path. The path must use forward slashes as path separator.
---
--- Does not check if the path is a valid Windows path. Invalid paths will give invalid results.
---
--- Examples:
--- - `\\.\C:\foo\bar` -> `\\.\C:`, `\foo\bar`
--- - `\\?\UNC\server\share\foo\bar` -> `\\?\UNC\server\share`, `\foo\bar`
--- - `\\.\system07\C$\foo\bar` -> `\\.\system07`, `\C$\foo\bar`
--- - `C:\foo\bar` -> `C:`, `\foo\bar`
--- - `C:foo\bar` -> `C:`, `foo\bar`
---
--- @param p string Path to split.
--- @return string, string, boolean : prefix, body, whether path is invalid.
local function split_windows_path(p)
  local prefix = ""

  --- Match pattern. If there is a match, move the matched pattern from the path to the prefix.
  --- Returns the matched pattern.
  ---
  --- @param pattern string Pattern to match.
  --- @return string|nil Matched pattern
  local function match_to_prefix(pattern)
    local match = p:match(pattern)

    if match then
      prefix = prefix .. match --[[ @as string ]]
      p = p:sub(#match + 1)
    end

    return match
  end

  local function process_unc_path()
    return match_to_prefix "[^/]+/+[^/]+/+"
  end

  if match_to_prefix "^//[?.]/" then
    -- Device paths
    local device = match_to_prefix "[^/]+/+"

    -- Return early if device pattern doesn't match, or if device is UNC and it's not a valid path
    if not device or (device:match "^UNC/+$" and not process_unc_path()) then
      return prefix, p, false
    end
  elseif match_to_prefix "^//" then
    -- Process UNC path, return early if it's invalid
    if not process_unc_path() then
      return prefix, p, false
    end
  elseif p:match "^%w:" then
    -- Drive paths
    prefix, p = p:sub(1, 2), p:sub(3)
  end

  -- If there are slashes at the end of the prefix, move them to the start of the body. This is to
  -- ensure that the body is treated as an absolute path. For paths like C:foo/bar, there are no
  -- slashes at the end of the prefix, so it will be treated as a relative path, as it should be.
  local trailing_slash = prefix:match "/+$"

  if trailing_slash then
    prefix = prefix:sub(1, -1 - #trailing_slash)
    p = trailing_slash .. p --[[ @as string ]]
  end

  return prefix, p, true
end

--- Resolve `.` and `..` components in a POSIX-style path. This also removes extraneous slashes.
--- `..` is not resolved if the path is relative and resolving it requires the path to be absolute.
--- If a relative path resolves to the current directory, an empty string is returned.
---
---@see M.normalize()
---@param p string Path to resolve.
---@return string # Resolved path.
local function path_resolve_dot(p)
  local is_path_absolute = vim.startswith(p, "/")
  local new_path_components = {}

  for component in vim.gsplit(p, "/") do
    if component == "." or component == "" then
      -- Skip `.` components and empty components
    elseif component == ".." then
      if #new_path_components > 0 and new_path_components[#new_path_components] ~= ".." then
        -- For `..`, remove the last component if we're still inside the current directory, except
        -- when the last component is `..` itself
        table.remove(new_path_components)
      elseif is_path_absolute then
        -- Reached the root directory in absolute path, do nothing
      else
        -- Reached current directory in relative path, add `..` to the path
        table.insert(new_path_components, component)
      end
    else
      table.insert(new_path_components, component)
    end
  end

  return (is_path_absolute and "/" or "") .. table.concat(new_path_components, "/")
end

--- Resolves '.' and '..' in the path, removes extra path separator.
---
--- For Windows, converts separator `\` to `/` to simplify many operations.
---
--- Credit to famiu. This is basically neovim core `vim.fs.normalize`.
---@param p string path
---@return string
local function normalize_path(p)
  if p == "" or is_uri(p) then
    return p
  end

  if iswin then
    p = p:gsub("\\", "/")
  end

  local double_slash = vim.startswith(p, "//") and not vim.startswith(p, "///")
  local prefix = ""

  if iswin then
    local valid
    prefix, p, valid = split_windows_path(p)
    if not valid then
      return prefix .. p
    end
    prefix = prefix:gsub("/+", "/")
  end

  p = path_resolve_dot(p)
  p = (double_slash and "/" or "") .. prefix .. p

  if p == "" then
    p = "."
  end

  return p
end

---@class plenary.Path
---@field path plenary.path
---@field filename string path as a string
---
--- internal string representation of the path that's normalized and uses `/`
--- as path separator. makes many other operations much easier to work with.
---@field private _name string
---@field private _sep string path separator taking into account 'shellslash' on windows
---@field private _absolute string? absolute path
---@field private _cwd string? cwd path
---@field private _fs_stat table fs_stat
local Path = {
  path = path,
}

Path.__index = function(t, k)
  local raw = rawget(Path, k)
  if raw then
    return raw
  end

  if k == "_cwd" then
    local cwd = uv.fs_realpath "."
    if cwd ~= nil then
      cwd = (cwd:gsub(path._uv_sep, "/"))
    end
    t._cwd = cwd
    return t._cwd
  end

  if k == "_absolute" then
    local absolute = uv.fs_realpath(t._name)
    if absolute ~= nil then
      absolute = (absolute:gsub(path._uv_sep, "/"))
    end
    t._absolute = absolute
    return absolute
  end

  if k == "_fs_stat" then
    t._fs_stat = uv.fs_stat(t._absolute or t._name) or {}
    return t._fs_stat
  end
end

---@param other plenary.Path|string
---@return plenary.Path
Path.__div = function(self, other)
  assert(Path.is_path(self))
  assert(Path.is_path(other) or type(other) == "string")

  return self:joinpath(other)
end

---@return string
Path.__tostring = function(self)
  return self._name
end

-- TODO: See where we concat the table, and maybe we could make this work.
Path.__concat = function(self, other)
  return self.filename .. other
end

Path.is_path = function(a)
  return getmetatable(a) == Path
end

---@param parts string[]
---@param sep string
---@return string
local function unix_path_str(parts, sep)
  -- any sep other than `/` is not a valid sep but allowing for backwards compat reasons
  local flat_parts = {}
  for _, part in ipairs(parts) do
    vim.list_extend(flat_parts, vim.split(part, sep))
  end

  return (table.concat(flat_parts, sep):gsub(sep .. "+", sep))
end

---@param parts string[]
---@param sep string
---@return string
local function windows_path_str(parts, sep)
  local disk = parts[1]:match "^[%a]:"
  local is_disk_root = parts[1]:match "^[%a]:[\\/]" ~= nil
  local is_unc = parts[1]:match "^\\\\" or parts[1]:match "^//"

  local flat_parts = {}
  for _, part in ipairs(parts) do
    vim.list_extend(flat_parts, vim.split(part, "[\\/]"))
  end

  if not is_disk_root and flat_parts[1] == disk then
    table.remove(flat_parts, 1)
    local p = disk .. table.concat(flat_parts, sep)
    return (p:gsub(sep .. "+", sep))
  end
  if is_unc then
    table.remove(flat_parts, 1)
    table.remove(flat_parts, 1)
    local body = (table.concat(flat_parts, sep):gsub(sep .. "+", sep))
    return sep .. sep .. body
  end
  return (table.concat(flat_parts, sep):gsub(sep .. "+", sep))
end

---@return plenary.Path
function Path:new(...)
  local args = { ... }

  if type(self) == "string" then
    table.insert(args, 1, self)
    self = Path
  end

  local path_input
  if #args == 1 then
    if Path.is_path(args[1]) then
      local p = args[1] ---@cast p plenary.Path
      return p
    end
    if type(args[1]) == "table" then
      path_input = args[1]
    else
      assert(type(args[1]) == "string", "unexpected path input\n" .. vim.inspect(path_input))
      path_input = args
    end
  else
    path_input = args
  end

  assert(type(path_input) == "table", vim.inspect(path_input))
  ---@cast path_input {[integer]: (string)|plenary.Path, sep: string?}

  local sep = path.sep
  sep = path_input.sep or path.sep
  path_input.sep = nil
  path_input = vim.tbl_map(function(part)
    if Path.is_path(part) then
      return part.filename
    else
      assert(type(part) == "string", vim.inspect(path_input))
      return vim.trim(part)
    end
  end, path_input)

  assert(#path_input > 0, "can't create Path out of nothing")

  local path_string
  if iswin then
    path_string = windows_path_str(path_input, sep)
  else
    path_string = unix_path_str(path_input, sep)
  end

  local proxy = {
    -- precompute normalized path using `/` as sep
    _name = normalize_path(path_string),
    filename = path_string,
    _sep = sep,
  }

  setmetatable(proxy, Path)

  local obj = { __inner = proxy }
  setmetatable(obj, {
    __index = function(_, k)
      return proxy[k]
    end,
    __newindex = function(t, k, val)
      if k == "filename" then
        proxy.filename = val
        proxy._name = normalize_path(val)
        proxy._absolute = nil
        proxy._fs_stat = nil
      elseif k == "_name" then
        proxy.filename = (val:gsub("/", t._sep))
        proxy._name = val
        proxy._absolute = nil
        proxy._fs_stat = nil
      else
        proxy[k] = val
      end
    end,
    ---@return plenary.Path
    __div = function(t, other)
      return Path.__div(t, other)
    end,
    ---@return string
    __concat = function(t, other)
      return Path.__concat(t, other)
    end,
    ---@return string
    __tostring = function(t)
      return Path.__tostring(t)
    end,
    __metatable = Path,
  })

  return obj
end

---@return string
function Path:absolute()
  if self:is_absolute() then
    return (self._name:gsub("/", self._sep))
  end
  return (normalize_path(self._cwd .. self._sep .. self._name):gsub("/", self._sep))
end

---@return string
function Path:_fs_filename()
  return self:absolute() or self.filename
end

---@return table
function Path:_stat()
  return self._fs_stat
end

---@return number
function Path:_st_mode()
  return self:_stat().mode or 0
end

---@return boolean
function Path:exists()
  return not vim.tbl_isempty(self:_stat())
end

---@return boolean
function Path:is_dir()
  return self:_stat().type == "directory"
end

---@return boolean
function Path:is_file()
  return self:_stat().type == "file"
end

--- For POSIX path, anything starting with a `/` is considered a absolute path.
---
---
--- For Windows, it's a little more involved.
---
--- Disk names are single letters. They MUST be followed by a `:` + separator to be
--- considered an absolute path. eg.
--- C:\Documents\Newsletters\Summer2018.pdf -> An absolute file path from the root of drive C:.

--- UNC paths are also considered absolute. eg. \\Server2\Share\Test\Foo.txt
---
--- Any other valid paths are relative. eg.
--- C:Projects\apilibrary\apilibrary.sln -> A relative path from the current directory of the C: drive.
--- 2018\January.xlsx -> A relative path to a file in a subdirectory of the current directory.
--- \Program Files\Custom Utilities\StringFinder.exe -> A relative path from the root of the current drive.
--- ..\Publications\TravelBrochure.pdf -> A relative path to a file in a directory starting from the current directory.
---@return boolean
function Path:is_absolute()
  if not iswin then
    return string.sub(self._name, 1, 1) == "/"
  end

  if string.match(self._name, "^[%a]:/.*$") ~= nil then
    return true
  elseif string.match(self._name, "^//") then
    return true
  end

  return false
end

---@return plenary.Path
function Path:joinpath(...)
  return Path:new(self._name, ...)
end

--- Make path relative to another.
---
--- No-op if path is a URI.
---@param cwd string? path to make relative to (default: cwd)
---@return string # new filename
function Path:make_relative(cwd)
  if is_uri(self._name) then
    return self.filename
  end

  cwd = Path:new(vim.F.if_nil(cwd, self._cwd))._name

  if self._name == cwd then
    self._name = "."
    return self.filename
  end

  if cwd:sub(#cwd, #cwd) ~= "/" then
    cwd = cwd .. "/"
  end

  if not self:is_absolute() then
    self._name = normalize_path(cwd .. self._name)
  end

  -- TODO: doesn't handle distant relative cwd well
  -- eg. cwd = '/tmp/foo' and path = '/home/user/bar'
  --     would be something like '/tmp/foo/../../home/user/bar'?
  -- I'm not even sure, check later
  if self._name:sub(1, #cwd) == cwd then
    self._name = self._name:sub(#cwd + 1, -1)
  else
    self._name = normalize_path(self.filename)
  end
  return self.filename
end

--- Makes the path relative to cwd or provided path and resolves any internal
--- '.' and '..' in relative paths according. Substitutes home directory
--- with `~` if applicable. Deduplicates path separators and trims any trailing
--- separators.
---
--- No-op if path is a URI.
---@param cwd string? path to make relative to (default: cwd)
---@return string
function Path:normalize(cwd)
  if is_uri(self._name) then
    return self.filename
  end

  print(self.filename, self._name)
  self:make_relative(cwd)

  local home = path.home
  if home:sub(-1) ~= self._sep then
    home = home .. self._sep
  end

  local start, finish = self._name:find(home, 1, true)
  if start == 1 then
    self._name = "~/" .. self._name:sub(finish + 1, -1)
  end

  return self.filename
end

return Path
