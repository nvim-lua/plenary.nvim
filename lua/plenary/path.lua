--- Path.lua
---
--- Goal: Create objects that are extremely similar to Python's `Path` Objects.
--- Reference: https://docs.python.org/3/library/pathlib.html

local uv = vim.loop

local F = require('plenary.functional')



local S_IF = {
  -- S_IFDIR  = 0o040000  # directory
  DIR = 0x4000,
  -- S_IFREG  = 0o100000  # regular file
  REG = 0x8000,
}

local path = {}

path.sep = (function()
  if string.lower(jit.os) == 'linux' or string.lower(jit.os) == 'osx' then
    return '/'
  else
    return '\\'
  end
end)()

path.S_IF = S_IF

local band = function(reg, value)
  return bit.band(reg, value) == reg
end

-- S_IFCHR  = 0o020000  # character device
-- S_IFBLK  = 0o060000  # block device
-- S_IFIFO  = 0o010000  # fifo (named pipe)
-- S_IFLNK  = 0o120000  # symbolic link
-- S_IFSOCK = 0o140000  # socket file


local Path = {
  path = path,
}

local check_self = function(self)
  if type(self) == 'string' then
    return Path:new(self)
  end

  return self
end

Path.__index = Path

-- TODO: Could use this to not have to call new... not sure
-- Path.__call = Path:new

Path.__div = function(self, other)
  assert(Path.is_path(self))
  assert(Path.is_path(other) or type(other) == 'string')

  return self:joinpath(other)
end

Path.__tostring = function(self)
  return self.filename
end

-- TODO: See where we concat the table, and maybe we could make this work.
Path.__concat = function(self, other)
  print(self, other)
  return self.filename .. other
end

Path.is_path = function(a)
  return getmetatable(a) == Path
end


function Path:new(...)
  local args = {...}

  if type(self) == 'string' then
    table.insert(args, 1, self)
    self = Path
  end

  local path_input
  if #args == 1 then
    path_input = args[1]
  else
    path_input = args
  end

  -- If we already have a Path, it's fine.
  --   Just return it
  if Path.is_path(path_input) then
    return path_input
  end

  -- TODO: Should probably remove and dumb stuff like double seps, periods in the middle, etc.
  local sep = path.sep
  if type(path_input) == 'table' then
    sep = path_input.sep or path.sep
    path_input.sep = nil
  end

  local path_string
  if type(path_input) == 'table' then
    -- TODO: It's possible this could be done more elegantly with __concat
    --       But I'm unsure of what we'd do to make that happen
    local path_objs = {}
    for _, v in ipairs(path_input) do
      if Path.is_path(v) then
        table.insert(path_objs, v.filename)
      else
        assert(type(v) == 'string')
        table.insert(path_objs, v)
      end
    end

    path_string = table.concat(path_objs, sep)
  else
    assert(type(path_input) == 'string', vim.inspect(path_input))
    path_string = path_input
  end

  local obj = {
    filename = path_string,

    _sep = sep,

    -- Cached values
    _absolute = uv.fs_realpath(path_string),
    _cwd = uv.fs_realpath('.'),
  }

  setmetatable(obj, Path)

  return obj
end

function Path:_stat()
  return uv.fs_stat(self:absolute() or self.filename) or {}
  -- local stat = uv.fs_stat(self:absolute())
  -- if not self._absolute then return {} end

  -- if not self._stat_result then
  --   self._stat_result =
  -- end

  -- return self._stat_result
end

function Path:_st_mode()
  return self:_stat().mode or 0
end


function Path:joinpath(...)
  return Path:new(self.filename, ...)
end

function Path:absolute()
  if self:is_absolute() then
    return self.filename
  else
    return self._absolute or table.concat({self._cwd, self.filename}, self.sep)
  end
end

function Path:exists()
  return not vim.tbl_isempty(self:_stat())
end

function Path:expand()
  -- TODO support windows
  local expanded
  if string.find(self.filename, "~") then
    expanded = string.gsub(self.filename, "^~", vim.loop.os_homedir())
  elseif string.find(self.filename, "^%.") then
    expanded = vim.loop.fs_realpath(self.filename)
    if expanded == nil then
     expanded = vim.fn.fnamemodify(self.filename, ":p")
   end
  elseif string.find(self.filename, "%$") then
    local rep = string.match(self.filename, "([^%$][^/]*)")
    local val = os.getenv(rep)
    if val then
      expanded = string.gsub(string.gsub(self.filename, rep, val), "%$", "")
    else
      expanded = nil
    end
  else
    expanded = self.filename
  end
  return expanded and expanded or error("Path not valid")
end

function Path:mkdir(opts)
  opts = opts or {}

  local mode = opts.mode or 448 -- 0700 -> decimal
  local parents = F.if_nil(opts.parents, false)
  local exists_ok = F.if_nil(opts.exists_ok, true)

  if not exists_ok and self:exists() then
    error("FileExistsError:" .. self:absolute())
  end

  if not uv.fs_mkdir(self:absolute() or self.filename,  mode) then
    if parents then
      -- TODO: Find all the parents
      error("Not implemented")
    end

    error('FileNotFoundError')
  end

  return true
end

function Path:rmdir()
  if not self:exists() then
    return
  end

  uv.fs_rmdir(self:absolute())
end

-- Path:is_* {{{
function Path:is_dir()
  -- TODO: I wonder when this would be better, if ever.
  -- return self:_stat().type == 'directory'

  return band(S_IF.DIR, self:_st_mode())
end

function Path:is_file()
  return band(S_IF.REG, self:_st_mode())
end

function Path:is_absolute()
  -- TODO(windows)
  return string.sub(self.filename, 1, 1) == self._sep
end
-- }}}

function Path:parents()
  -- local parts = vim.split(self:absolute())
end

function Path:is_file()
  local stat = vim.loop.fs_stat(self:expand())
  if stat then
    return stat.type == "file" and true or nil
  end
end

-- TODO:
--  Maybe I can use libuv for this?
function Path:open()
end

function Path:close()
end

-- TODO: Asyncify this and use vim.wait in the meantime.
--  This will allow other events to happen while we're waiting!
function Path:read()
  self = check_self(self)

  local fd = assert(uv.fs_open(self:expand(), "r", 438)) -- for some reason test won't pass with absolute
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0))
  assert(uv.fs_close(fd))

  return data
end

function Path:head(lines)
  lines = lines or 10
  self = check_self(self)
  local chunk_size = 256

  local fd = assert(uv.fs_open(self:expand(), "r", 438))
  local stat = assert(uv.fs_fstat(fd))
  if stat.type ~= 'file' then return nil end

  local data = ''
  local index, count = 0, 0
  while count < lines and index < stat.size do
    local read_chunk = assert(uv.fs_read(fd, chunk_size, index))

    local i = 0
    for char in read_chunk:gmatch"." do
      if char == '\n' then
        count = count + 1
        if count >= lines then break end
      end
      index = index + 1
      i = i + 1
    end
    data = data .. read_chunk:sub(1, i)
  end
  assert(uv.fs_close(fd))

  -- Remove potential newline at end of file
  if data:sub(-1) == '\n' then data = data:sub(1, -2) end

  return data
end

function Path:tail(lines)
  lines = lines or 10
  self = check_self(self)
  local chunk_size = 256

  local fd = assert(uv.fs_open(self:expand(), "r", 438))
  local stat = assert(uv.fs_fstat(fd))
  if stat.type ~= 'file' then return nil end

  local data = ''
  local index, count = stat.size - 1, 0
  while count < lines and index > 0 do
    local real_index = index - chunk_size
    if real_index < 0 then
      chunk_size = chunk_size + real_index
      real_index = 0
    end

    local read_chunk = assert(uv.fs_read(fd, chunk_size, real_index))

    local i = #read_chunk
    while i > 0 do
      local char = read_chunk:sub(i, i)
      if char == '\n' then
        count = count + 1
        if count >= lines then break end
      end
      index = index - 1
      i = i - 1
    end
    data = read_chunk:sub(i + 1, #read_chunk) .. data
  end
  assert(uv.fs_close(fd))

  return data
end

function Path:readlines()
  self = check_self(self)

  local data = self:read()

  data = data:gsub("\r", "")
  return vim.split(data, "\n")
end

function Path:iter()
  local data = self:readlines()
  local i = 0
  local n = table.getn(data)
  return function()
    i = i + 1
    if i <= n then return data[i] end
  end
end

return Path
