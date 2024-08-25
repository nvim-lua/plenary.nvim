local uv = vim.loop
local iswin = uv.os_uname().sysname == "Windows_NT"
local hasshellslash = vim.fn.exists "+shellslash" == 1

---@class plenary._Path
---@field sep string
---@field altsep string
---@field has_drv boolean
---@field convert_altsep fun(self: plenary._Path, p:string): string
---@field split_root fun(self: plenary._Path, part:string): string, string, string

---@class plenary._WindowsPath : plenary._Path
local _WindowsPath = {
  sep = "\\",
  altsep = "/",
  has_drv = true,
}

setmetatable(_WindowsPath, { __index = _WindowsPath })

---@param p string
---@return string
function _WindowsPath:convert_altsep(p)
  return (p:gsub(self.altsep, self.sep))
end

---@param part string path
---@return string drv
---@return string root
---@return string relpath
function _WindowsPath:split_root(part)
  -- https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats
  local prefix = ""
  local first, second = part:sub(1, 1), part:sub(2, 2)

  if first == self.sep and second == self.sep then
    prefix, part = self:_split_extended_path(part)
    first, second = part:sub(1, 1), part:sub(2, 2)
  end

  local third = part:sub(3, 3)

  if first == self.sep and second == self.sep and third ~= self.sep then
    -- is a UNC path:
    -- vvvvvvvvvvvvvvvvvvvvv root
    -- \\machine\mountpoint\directory\etc\...
    --            directory ^^^^^^^^^^^^^^

    local index = part:find(self.sep, 3)
    if index ~= nil then
      local index2 = part:find(self.sep, index + 1)
      if index2 ~= index + 1 then
        if index2 == nil then
          index2 = #part
        end

        if prefix ~= "" then
          return prefix + part:sub(2, index2 - 1), self.sep, part:sub(index2 + 1)
        else
          return part:sub(1, index2 - 1), self.sep, part:sub(index2 + 1)
        end
      end
    end
  end

  local drv, root = "", ""
  if second == ":" and first:match "%a" then
    drv, part = part:sub(1, 2), part:sub(3)
    first = third
  end

  if first == self.sep then
    root = first
    part = part:gsub("^" .. self.sep .. "+", "")
  end

  return prefix .. drv, root, part
end

---@param p string path
---@return string
---@return string
function _WindowsPath:_split_extended_path(p)
  local ext_prefix = [[\\?\]]
  local prefix = ""

  if p:sub(1, #ext_prefix) == ext_prefix then
    prefix = p:sub(1, 4)
    p = p:sub(5)
    if p:sub(1, 3) == "UNC" .. self.sep then
      prefix = prefix .. p:sub(1, 3)
      p = self.sep .. p:sub(4)
    end
  end

  return prefix, p
end

---@class plenary._PosixPath : plenary._Path
local _PosixPath = {
  sep = "/",
  altsep = "",
  has_drv = false,
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
  if part:sub(1) == self.sep then
    part = (part:gsub("^" .. self.sep, ""))
    return "", self.sep, part:sub(2, #part)
  end
  return "", "", part
end

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
---@param _path plenary._Path
---@return string drv
---@return string root
---@return string[]
local function parse_parts(parts, _path)
  local drv, root, rel, parsed = "", "", "", {}

  for i = #parts, 1, -1 do
    local part = parts[i]
    part = _path:convert_altsep(part)

    drv, root, rel = _path:split_root(part)

    if rel:match(_path.sep) then
      local relparts = vim.split(rel, _path.sep)
      for j = #relparts, 1, -1 do
        local p = relparts[j]
        if p ~= "" and p ~= "." then
          table.insert(parsed, p)
        end
      end
    else
      if rel ~= "" and rel ~= "." then
        table.insert(parsed, rel)
      end
    end

    if drv or root then
      if not drv then
        for k = #parts, 1, -1 do
          local p = parts[k]
          p = _path:convert_altsep(p)
          drv = _path:split_root(p)
          if drv then
            break
          end
        end

        break
      end
    end
  end

  if drv or root then
    table.insert(parsed, drv .. root)
  end

  local n = #parsed
  for i = 1, math.floor(n / 2) do
    parsed[i], parsed[n - i + 1] = parsed[n - i + 1], parsed[i]
  end

  return drv, root, parsed
end

---@class plenary.Path2
---@field path plenary.path2
---@field private _path plenary._Path
---@field drv string drive name, eg. 'C:' (only for Windows)
---@field root string root path (excludes drive name)
---@field parts string[] path parts excluding separators
---
---@field filename string
---@field private _absolute string? lazy eval'ed fully resolved absolute path
local Path = { path = path }

Path.__index = function(t, k)
  local raw = rawget(Path, k)
  if raw then
    return raw
  end

  if k == "filename" then
    t.filename = t:_filename()
    return t.filename
  end
end

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

  local parts = {}
  for _, a in ipairs(args) do
    if self.is_path(a) then
      vim.list_extend(parts, a.parts)
    else
      if a ~= "" then
        table.insert(parts, a)
      end
    end
  end

  local _path = iswin and _WindowsPath or _PosixPath
  local drv, root
  drv, root, parts = parse_parts(parts, _path)

  local proxy = { _path = _path, drv = drv, root = root, parts = parts }
  setmetatable(proxy, Path)

  local obj = { __inner = proxy }
  setmetatable(obj, {
    __index = function(_, k)
      return proxy[k]
    end,
    __newindex = function(_, k, val)
      if k == "_absolute" then
        proxy[k] = val
        return
      end
      error "'Path' object is read-only"
    end,
    __metatable = Path,
  })

  return obj
end

---@param x any
---@return boolean
function Path.is_path(x)
  return getmetatable(x) == Path
end

---@private
---@param drv string?
---@param root string?
---@param parts string[]?
---@return string
function Path:_filename(drv, root, parts)
  drv = vim.F.if_nil(drv, self.drv)
  drv = self.drv ~= "" and self.drv:gsub(self._path.sep, path.sep) or ""

  if self._path.has_drv and drv == "" then
    root = ""
  else
    root = vim.F.if_nil(root, self.root)
    root = self.root ~= "" and path.sep:rep(#self.root) or ""
  end

  parts = vim.F.if_nil(parts, self.parts)
  local relparts = table.concat(vim.list_slice(parts, 2), path.sep)

  return drv .. root .. relparts
end

---@return boolean
function Path:is_absolute()
  if self.root == "" then
    return false
  end

  return self._path.has_drv and self.drv ~= ""
end

---@param parts string[] path parts
---@return string[]
local function resolve_dots(parts)
  local new_parts = {}
  for _, part in ipairs(parts) do
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
--- respects 'shellslash' on Windows
---@return string
function Path:absolute()
  if self._absolute then
    return self._absolute
  end

  local parts = resolve_dots(self.parts)
  local filename = self:_filename(self.drv, self.root, parts)
  if self:is_absolute() then
    self._absolute = filename
  else
    -- using fs_realpath over fnamemodify
    -- fs_realpath resolves symlinks whereas fnamemodify doesn't but we're
    -- resolving/normalizing the path anyways for reasons of compat with old Path
    self._absolute = uv.fs_realpath(self:_filename())
    if self.path.isshellslash then
      self._absolute = self._absolute:gsub("\\", path.sep)
    end
  end
  return self._absolute
end

---@param ... plenary.Path2Args
---@return plenary.Path2
function Path:joinpath(...)
  return Path:new { self, ... }
end

-- vim.o.shellslash = false
local p = Path:new("lua"):joinpath "plenary"
-- vim.print(p)
-- print(p.filename, p:is_absolute(), p:absolute())
-- vim.o.shellslash = true

return Path
