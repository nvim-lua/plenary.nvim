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
path.home = vim.loop.os_homedir()

path.sep = (function()
  if jit then
    if string.lower(jit.os) == 'linux' or string.lower(jit.os) == 'osx' then
      return '/'
    else
      return '\\'
    end
  else
    return package.config:sub(1, 1)
  end
end)()

path.S_IF = S_IF

local band = function(reg, value)
  return bit.band(reg, value) == reg
end

local concat_paths = function(...)
  return table.concat({...}, path.sep)
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

function Path:_fs_filename()
  return self:absolute() or self.filename
end

function Path:_stat()
  return uv.fs_stat(self:_fs_filename()) or {}
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
    return self._absolute or table.concat({self._cwd, self.filename}, self._sep)
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

function Path:make_relative(cwd)
  cwd = F.if_nil(cwd, self._cwd, cwd)
  if self.filename:sub(1, #cwd) == cwd  then
    local offset =  0
    -- if  cwd does ends in the os separator, we need to take it off
    if cwd:sub(#cwd, #cwd) ~= path.separator then
      offset = 1
    end

    self.filename = self.filename:sub(#cwd + 1 + offset, #self.filename)
  end

  return self.filename
end

function Path:normalize(cwd)
  cwd = F.if_nil(cwd, self._cwd, cwd)
  self:make_relative(cwd)
  -- Substitute home directory w/ "~"
  self.filename = self.filename:gsub("^" .. path.home, '~', 1)
  -- Remove double path seps, it's annoying
  self.filename = self.filename:gsub(path.sep .. path.sep, path.sep)

  return self.filename
end

local shorten = (function()
  if jit then
    local ffi = require('ffi') ffi.cdef [[
    typedef unsigned char char_u;
    char_u *shorten_dir(char_u *str);
    ]]
    return function(filename)
      if not filename then
        return filename
      end

      local c_str = ffi.new("char[?]", #filename + 1)
      ffi.copy(c_str, filename)
      return ffi.string(ffi.C.shorten_dir(c_str))
    end
  end
  return function(filename)
    return filename
  end
end)()

function Path:shorten()
  return shorten(self.filename)
end

function Path:mkdir(opts)
  opts = opts or {}

  local mode = opts.mode or 448 -- 0700 -> decimal
  local parents = F.if_nil(opts.parents, false, opts.parents)
  local exists_ok = F.if_nil(opts.exists_ok, true, opts.exists_ok)

  if not exists_ok and self:exists() then
    error("FileExistsError:" .. self:absolute())
  end

  if not uv.fs_mkdir(self:_fs_filename(),  mode) then
    if parents then
      local dirs = self:_split()
      local processed = ''
      for _, dir in ipairs(dirs) do
        if dir ~= '' then
          local joined = concat_paths(processed, dir)
          if processed == '' and self._sep == '\\' then
            joined = dir
          end
          local stat = uv.fs_stat(joined) or {}
          local file_mode = stat.mode or 0
          if band(S_IF.REG, file_mode) then
            error(string.format('%s is a regular file so we can\'t mkdir it', joined))
          elseif band(S_IF.DIR, file_mode) then
            processed = joined
          else
            if uv.fs_mkdir(joined, mode) then
              processed = joined
            else
              error('We couldn\'t mkdir: ' .. joined)
            end
          end
        end
      end
    else
      error('FileNotFoundError')
    end
  end

  return true
end

function Path:rmdir()
  if not self:exists() then
    return
  end

  uv.fs_rmdir(self:absolute())
end

function Path:touch(opts)
  opts = opts or {}

  local mode = opts.mode or 420
  local parents = F.if_nil(opts.parents, false, opts.parents)

  if self:exists() then
    local new_time = os.time()
    uv.fs_utime(self:_fs_filename(), new_time, new_time)
    return
  end

  if parents then
    Path:new(self:parents()):mkdir({ parents = true })
  end

  local fd = uv.fs_open(self:_fs_filename(), "w", mode)
  if not fd then error('Could not create file: ' .. self:_fs_filename()) end
  uv.fs_close(fd)

  return true
end

function Path:rm(opts)
  opts = opts or {}

  local recursive = F.if_nil(opts.recursive, false, opts.recursive)
  if recursive then
    local scan = require('plenary.scandir')
    local abs = self:absolute()

    -- first unlink all files
    scan.scan_dir(abs, { hidden = true, on_insert = function(file) uv.fs_unlink(file) end})

    local dirs = scan.scan_dir(abs, { add_dirs = true })
    -- iterate backwards to clean up remaining dirs
    for i = #dirs, 1, -1 do
      uv.fs_rmdir(dirs[i])
    end

    -- now only abs is missing
    uv.fs_rmdir(abs)
  else
    uv.fs_unlink(self:absolute())
  end
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
  if self._sep == '\\' then
    return string.match(self.filename, '^[A-Z]:\\.*$')
  end
  return string.sub(self.filename, 1, 1) == self._sep
end
-- }}}

function Path:_split()
  return vim.split(self:absolute(), self._sep)
end

function Path:parents()
  return self:absolute():match(string.format('^(.+)%s[^%s]+', self._sep, self._sep))
end

function Path:is_file()
  local stat = uv.fs_stat(self:expand())
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

function Path:write(txt, flag, mode)
  assert(flag, [[Path:write_text requires a flag! For example: 'w' or 'a']])

  mode = mode or 438

  local fd = assert(uv.fs_open(self:expand(), flag, mode))
  assert(uv.fs_write(fd, txt, -1))
  assert(uv.fs_close(fd))
end

-- TODO: Asyncify this and use vim.wait in the meantime.
--  This will allow other events to happen while we're waiting!
function Path:_read()
  self = check_self(self)

  local fd = assert(uv.fs_open(self:expand(), "r", 438)) -- for some reason test won't pass with absolute
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0))
  assert(uv.fs_close(fd))

  return data
end

function Path:_read_async(callback)
  vim.loop.fs_open(self.filename, "r", 438, function(err_open, fd)
    if err_open then
      print("We tried to open this file but couldn't. We failed with following error message: " .. err_open)
      return
    end
    vim.loop.fs_fstat(fd, function(err_fstat, stat)
      assert(not err_fstat, err_fstat)
      if stat.type ~= 'file' then return callback('') end
      vim.loop.fs_read(fd, stat.size, 0, function(err_read, data)
        assert(not err_read, err_read)
        vim.loop.fs_close(fd, function(err_close)
          assert(not err_close, err_close)
          return callback(data)
        end)
      end)
    end)
  end)
end

function Path:read(callback)
  if callback then
    return self:_read_async(callback)
  end
  return self:_read()
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
