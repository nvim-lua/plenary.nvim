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

path.sep = package.config:sub(1, 1)
path.S_IF = S_IF

local band = function(reg, value)
  return bit.band(reg, value) == reg
end

-- S_IFCHR  = 0o020000  # character device
-- S_IFBLK  = 0o060000  # block device
-- S_IFIFO  = 0o010000  # fifo (named pipe)
-- S_IFLNK  = 0o120000  # symbolic link
-- S_IFSOCK = 0o140000  # socket file

local Path = {}

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
    sep = path_input.sep
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

    path_string = table.concat(path_objs, self._sep)
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
  local parts = vim.split(self:absolute())
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
  local fd = assert(uv.fs_open(self:absolute(), "r", 438))
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0))
  assert(uv.fs_close(fd))

  return data
end

function Path:readlines()
  local data = self:read()

  data = data:gsub("\r", "")
  return vim.split(data, "\n")
end

return Path, path
