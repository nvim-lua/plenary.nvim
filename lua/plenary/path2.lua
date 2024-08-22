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
- [ ]  Path:_fs_filename
- [ ]  Path:_stat
- [ ]  Path:_st_mode
- [ ]  Path:joinpath
- [ ]  Path:absolute
- [ ]  Path:exists
- [ ]  Path:expand
- [ ]  Path:make_relative
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
- [ ]  Path:is_absolute
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
---@field home? string home directory path
---@field sep string OS path separator
---@field root fun():string root directory path
---@field S_IF { DIR: integer, REG: integer } stat filetype bitmask
local path = setmetatable({
  home = vim.loop.os_homedir(),
  S_IF = S_IF,
}, {
  __index = function(t, k)
    local raw = rawget(t, k)
    if raw then
      return raw
    end

    if not iswin then
      t.sep = "/"
      return t.sep
    end

    return (hasshellslash and vim.o.shellslash) and "/" or "\\"
  end,
})

path.root = (function()
  if path.sep == "/" then
    return function()
      return "/"
    end
  else
    return function(base)
      base = base or vim.loop.cwd()
      return base:sub(1, 1) .. ":\\"
    end
  end
end)()

local function is_uri(filename)
  local char = string.byte(filename, 1) or 0

  -- is alpha?
  if char < 65 or (char > 90 and char < 97) or char > 122 then
    return false
  end

  for i = 2, #filename do
    char = string.byte(filename, i)
    if char == 58 then -- `:`
      return i < #filename and string.byte(filename, i + 1) ~= 92 -- `\`
    elseif
      not (
        (char >= 48 and char <= 57) -- 0-9
        or (char >= 65 and char <= 90) -- A-Z
        or (char >= 97 and char <= 122) -- a-z
        or char == 43 -- `+`
        or char == 46 -- `.`
        or char == 45 -- `-`
      )
    then
      return false
    end
  end
  return false
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
local function split_windows_p(p)
  local prefix = ""

  --- Match pattern. If there is a match, move the matched pattern from the p to the prefix.
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
    return match_to_prefix "[^\\]+\\+[^\\]+\\+"
  end

  if match_to_prefix "^\\\\[?.]\\" then
    -- Device ps
    local device = match_to_prefix "[^\\]+\\+"

    -- Return early if device pattern doesn't match, or if device is UNC and it's not a valid p
    if not device or (device:match "^UNC\\+$" and not process_unc_path()) then
      return prefix, p, false
    end
  elseif match_to_prefix "^\\\\" then
    -- Process UNC p, return early if it's invalid
    if not process_unc_path() then
      return prefix, p, false
    end
  elseif p:match "^%w:" then
    -- Drive ps
    prefix, p = p:sub(1, 2), p:sub(3)
  end

  -- If there are slashes at the end of the prefix, move them to the start of the body. This is to
  -- ensure that the body is treated as an absolute p. For ps like C:foo\\bar, there are no
  -- slashes at the end of the prefix, so it will be treated as a relative p, as it should be.
  local trailing_slash = prefix:match "\\+$"

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
    if component == "." or component == "" then -- luacheck: ignore 542
      -- Skip `.` components and empty components
    elseif component == ".." then
      if #new_path_components > 0 and new_path_components[#new_path_components] ~= ".." then
        -- For `..`, remove the last component if we're still inside the current directory, except
        -- when the last component is `..` itself
        table.remove(new_path_components)
      elseif is_path_absolute then -- luacheck: ignore 542
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
    prefix, p, valid = split_windows_p(p)
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
---@field private _filename string
---@field private _sep string path separator
---@field private _absolute string absolute path
---@field private _cwd string cwd path
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
    t._cwd = cwd
    return cwd
  end

  if k == "_absolute" then
    local absolute = uv.fs_realpath(t.filename)
    t._absolute = absolute
    return absolute
  end
end

Path.__newindex = function(t, k, value)
  if k == "filename" then
    error "'filename' field is immutable"
  end
  return rawset(t, k, value)
end

Path.__div = function(self, other)
  assert(Path.is_path(self))
  assert(Path.is_path(other) or type(other) == "string")

  return self:joinpath(other)
end

Path.__tostring = function(self)
  return clean(self.filename)
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

  -- if type(path_input) == "string" then
  --   if iswin then
  --     if path_input:match "^[%a]:[\\/].*$" then
  --     end
  --     path_input = vim.split(path_input, "[\\/]")
  --   else
  --     path_input = vim.split(path_input, sep)
  --   end
  -- end

  -- if type(path_input) == "table" then
  --   local path_objs = {}
  --   for _, v in ipairs(path_input) do
  --     if Path.is_path(v) then
  --       table.insert(path_objs, v.filename)
  --     else
  --       assert(type(v) == "string")
  --       table.insert(path_objs, v)
  --     end
  --   end

  --   if iswin and path_objs[1]:match "^[%a]:$" then
  --     local disk = path_objs[1]
  --     table.remove(path_objs, 1)
  --     path_string = disk .. table.concat(path_objs, sep)
  --   else
  --     path_string = table.concat(path_objs, sep)
  --   end
  -- else
  --   error("unexpected path input\n" .. vim.inspect(path_input))
  -- end

  local obj = {
    -- precompute normalized path using `/` as sep
    _filename = normalize_path(path_string),
    filename = path_string,
    _sep = sep,
  }

  setmetatable(obj, Path)

  return obj
end

--- For POSIX path, anything starting with a `/` is considered a absolute path.
---
---
--- For Windows, it's a little more involved.
---
--- Disk names are single letters. They MUST be followed by a separator to be
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
    return string.sub(self._filename, 1, 1) == "/"
  end

  if string.match(self._filename, "^[%a]:/.*$") ~= nil then
    return true
  elseif string.match(self._filename, "^//") then
    return true
  end

  return false
end

---@return string
function Path:absolute()
  if self:is_absolute() then
    return self.filename
  end
  return (normalize_path(self._cwd .. self._sep .. self._filename):gsub("/", self._sep))
end

vim.o.shellslash = false
-- -- local p = Path:new { "C:", "README.md" }
local p = Path:new { "C:\\Documents\\Newsletters\\Summer2018.pdf" }
print(p.filename, p:is_absolute(), p:absolute())
vim.o.shellslash = true

return Path
