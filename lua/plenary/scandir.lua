local Path = require'plenary.path'
local os_sep = Path.path.sep

local uv = vim.loop

local m = {}

local get_gitignore = function(path)
  local gitignore = {}
  local p = Path:new(path .. os_sep .. '.gitignore')
  if not p:exists() then return nil end
  for v in p:iter() do
    if v ~= '' then
      local w = v:gsub('%#.*', '')
      w = w:gsub('%.', '%%.')
      w = w:gsub('%*', '%.%*')
      if w ~= '' then
        table.insert(gitignore, w)
      end
    end
  end
  return gitignore
end

local interpret_gitignore = function(gitignore, entry)
  for _, v in ipairs(gitignore) do
    if entry:match(v) then return false end
  end
  return true
end

local handle_depth = function(base_paths, entry, depth)
  for _, v in ipairs(base_paths) do
    if entry:find(v, 1, true) then
      local cut = entry:sub(#v + 1, -1)
      cut = cut:sub(1, 1) == os_sep and cut:sub(2, -1) or cut
      local _, count = cut:gsub(os_sep, "")
      if depth <= (count + 1) then
        return nil
      end
    end
  end
  return entry
end

local gen_search_pat = function(pattern)
  if type(pattern) == 'string' then
    return function(entry)
      return entry:match(pattern)
    end
  elseif type(pattern) == 'table' then
    return function(entry)
      for _, v in ipairs(pattern) do
        if entry:match(v) then return true end
      end
      return false
    end
  end
end

local process_item = function(opts, name, typ, current_dir, next_dir, bp, data, giti, msp, cb)
  if opts.hidden or name:sub(1, 1) ~= '.' then
    if typ == 'directory' then
      local entry = current_dir .. '/' .. name
      if opts.depth then
        table.insert(next_dir, handle_depth(bp, entry, opts.depth))
      else
        table.insert(next_dir, entry)
      end
      if opts.add_dirs then
        if not msp or msp(entry) then
          table.insert(data, entry)
          if cb then cb(entry) end
        end
      end
    else
      local entry = current_dir .. '/' .. name
      if not giti or interpret_gitignore(giti, entry) then
        if not msp or msp(entry) then
          table.insert(data, entry)
          if cb then cb(entry) end
        end
      end
    end
  end
end

--- m.scan_dir
-- Search directory recursive and syncronous
-- @param path: string or table
--   string has to be a valid path
--   table has to be a array of valid paths
-- @param opts: table to change behavior
--   opts.hidden (bool):              if true hidden files will be added
--   opts.add_dirs (bool):            if true dirs will also be added to the results
--   opts.respect_gitignore (bool):   if true will only add files that are not ignored by the gitignore. Uses gitignore of the first path when a table is passed in(for now). Doesn't fail if gitignore is not found
--   opts.depth (int):                depth on how deep the search should go
--   opts.search_pattern (regex):     regex for which files will be added, string or table of strings
-- @param callback: on_stdout callback: Will be called for each element
-- @return array with files
m.scan_dir = function(path, opts, callback)
  opts = opts or {}

  local data = {}
  local base_paths = vim.tbl_flatten { path }
  local next_dir = vim.tbl_flatten { path }

  local gitignore = opts.respect_gitignore and get_gitignore(base_paths[1]) or nil
  local match_seach_pat = opts.search_pattern and gen_search_pat(opts.search_pattern) or nil

  repeat
    local current_dir = table.remove(next_dir, 1)
    local fd = uv.fs_scandir(current_dir)
    if fd == nil then break end
    while true do
      local name, typ = uv.fs_scandir_next(fd)
      if name == nil then break end
      process_item(opts, name, typ, current_dir, next_dir, base_paths, data, gitignore, match_seach_pat, callback)
    end
  until table.getn(next_dir) == 0
  return data
end

--- m.scan_dir_async
-- Search directory recursive and syncronous
-- @param path: string or table
--   string has to be a valid path
--   table has to be a array of valid paths
-- @param opts: table to change behavior
--   opts.hidden (bool):              if true hidden files will be added
--   opts.add_dirs (bool):            if true dirs will also be added to the results
--   opts.respect_gitignore (bool):   if true will only add files that are not ignored by git
--   opts.depth (int):                depth on how deep the search should go
--   opts.search_pattern (lua regex): depth on how deep the search should go
-- @param callback: table
--   callback.on_stdout(entry): Will be called for each element
--   callback.on_exit(content): Will be called at the end
m.scan_dir_async = function(path, opts, callback)
  callback = callback or {}
  opts = opts or {}

  local data = {}
  local base_paths = vim.tbl_flatten { path }
  local next_dir = vim.tbl_flatten{ path }
  local current_dir = table.remove(next_dir, 1)

  local gitignore = opts.respect_gitignore and get_gitignore() or nil
  local match_seach_pat = opts.search_pattern and gen_search_pat(opts.search_pattern) or nil

  local read_dir
  read_dir = function(err, fd)
    if not err then
      while true do
        local name, typ = uv.fs_scandir_next(fd)
        if name == nil then break end
        process_item(opts, name, typ, current_dir, next_dir, base_paths, data, gitignore, match_seach_pat, callback.on_stdout)
      end
      if table.getn(next_dir) == 0 then
        if callback.on_exit then callback.on_exit(data) end
      else
        current_dir = table.remove(next_dir, 1)
        uv.fs_scandir(current_dir, read_dir)
      end
    end
  end
  uv.fs_scandir(current_dir, read_dir)
end

local conv_to_octal = function(nr)
  local octal = 0
  local i = 1

  while nr ~= 0 do
    octal = octal + (nr % 8) * i
    nr = math.floor(nr / 8)
    i = i * 10
  end

  return octal;
end

local type_tbl = { [1]  = 'p', [2]  = 'c', [4]  = 'd', [6]  = 'b', [10] = '-', [12] = 'l', [14] = 's' }
local permissions_tbl = { '--x', '-w-', '-wx', 'r--', 'r-x', 'rw-', 'rwx' }
local bit_tbl = { 4, 2, 1 }

local gen_permissions = function(stat)
  local octal = string.format('%6d', conv_to_octal(stat.mode))
  local l4 = octal:sub(#octal - 3, -1)
  local bit = tonumber(l4:sub(1, 1))

  local result = type_tbl[tonumber(octal:sub(1, 2))] or '-'
  for i = 2, #l4 do
    result = result .. permissions_tbl[tonumber(l4:sub(i, i))]
    if bit - bit_tbl[i - 1] >= 0 then
      result = result:sub(1, -2) .. (bit_tbl[i - 1] == 1 and 't' or 's')
      bit = bit - bit_tbl[i - 1]
    end
  end
  return result
end

local gen_size = function(stat)
  local size = stat.size
  for _, v in ipairs{ '', 'K', 'M', 'G', 'T', 'P', 'E', 'Z' } do
    if math.abs(size) < 1024.0 then
      if math.abs(size) > 9 then
        return string.format("%3d%s", size, v)
      else
        return string.format("%3.1f%s", size, v)
      end
    end
    size = size / 1024.0
  end
  return string.format("%.1f%s", size, 'Y')
end

local gen_date = function(stat)
  return os.date('%b %d %H:%M', stat.mtime.sec)
end

local gen_id_cache = function(file)
  if os_sep == '\\' then return nil end -- Don't have a user/group row for windows

  local result = {}
  local p = Path:new(file)
  if not p:exists() then return nil end
  for v in p:iter() do
    if v ~= '' then
      local el = vim.split(v, ':')
      result[tonumber(el[3])] = el[1]
    end
  end

  return result
end

local gen_ls = function(data, path)
  local results = {}

  local users_tbl = gen_id_cache('/etc/passwd')
  local groups_tbl = gen_id_cache('/etc/group')

  local insert_in_results
  if not users_tbl and not groups_tbl then
    insert_in_results = function(...)
      local args = {...}
      table.insert(results, string.format('%10s %5s  %s  %s', args[1], args[2], args[5], args[6]))
    end
  else
    insert_in_results = function(...)
      table.insert(results, string.format('%10s %5s %s %s  %s  %s', ...))
    end
  end

  for _, v in ipairs(data) do
    local stat = Path:new(v):_stat()

    insert_in_results(
      gen_permissions(stat),
      gen_size(stat),
      users_tbl and users_tbl[stat.uid] or nil,
      groups_tbl and groups_tbl[stat.gid] or nil,
      gen_date(stat),
      v:sub(#path + 2, -1)
    )
  end
  return results
end

--- m.ls
-- List directory contents. Will always apply --long option.  Use scan_dir for without --long
-- @param path: string
--   string has to be a valid path
-- @param opts: table to change behavior
--   opts.hidden (bool):            if true hidden files will be added
--   opts.add_dirs (bool):          if true dirs will also be added to the results, default: true
--   opts.respect_gitignore (bool): if true will only add files that are not ignored by git
--   opts.depth (int):              depth on how deep the search should go, default: 1
-- @return array with formatted output
m.ls = function(path, opts)
  opts = opts or {}
  opts.depth = opts.depth or 1
  opts.add_dirs = opts.add_dirs or true
  local data = m.scan_dir(path, opts)

  return gen_ls(data, path)
end

--- m.ls_async
-- List directory contents. Will always apply --long option. Use scan_dir for without --long
-- @param path: string
--   string has to be a valid path
-- @param opts: table to change behavior
--   opts.hidden (bool):            if true hidden files will be added
--   opts.add_dirs (bool):          if true dirs will also be added to the results, default: true
--   opts.respect_gitignore (bool): if true will only add files that are not ignored by git
--   opts.depth (int):              depth on how deep the search should go, default: 1
-- @param callback: function(results)
m.ls_async = function(path, opts, callback)
  opts = opts or {}
  opts.depth = opts.depth or 1
  opts.add_dirs = opts.add_dirs or true

  m.scan_dir_async(path, opts, { on_exit = function(data)
    callback(gen_ls(data, path))
  end })
end

return m
