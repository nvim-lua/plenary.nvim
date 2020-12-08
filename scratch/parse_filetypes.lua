local lyaml = require'lyaml'

local read_file = function(filepath)
  local fd = vim.loop.fs_open(filepath, "r", 438)
  if fd == nil then return '' end
  local stat = assert(vim.loop.fs_fstat(fd))
  local data = assert(vim.loop.fs_read(fd, stat.size, 0))
  assert(vim.loop.fs_close(fd))
  return data
end

local parse_file = function()
  local yml_string = read_file('files.yml')
  local yml_table = lyaml.load(yml_string)
  local output = {}
  local intervention = {}
  local vim_filetypes = vim.fn.getcompletion('', 'filetype')

  for k, v in pairs(yml_table) do
    local filetype = string.lower(k)

    if not vim.tbl_contains(vim_filetypes, filetype) then
      filetype = nil
      if v.aliases then
        for _, ft in ipairs(v.aliases) do
          ft = string.lower(ft)
          if vim.tbl_contains(vim_filetypes, ft) then
            filetype = ft
            break
          end
        end
      end
    end

    if filetype then
      if v.extensions then
        for _, ext in ipairs(v.extensions) do
          if ext:sub(1, 1) == '.' then ext = ext:sub(2, #ext) end
          output[ext] = filetype
        end
      end

      -- For stuff like 'Makefile'
      if v.filenames then
        for _, fname in ipairs(v.filenames) do
          output[fname] = filetype
        end
      end
    else
      table.insert(intervention, 'Needs manual intervention for ' .. k)
    end
  end

  return vim.inspect(output), vim.fn.join(intervention, '\n')
end

local write_file = function(path, string)
  local fd = assert(vim.loop.fs_open(path, "w", 438))
  assert(vim.loop.fs_write(fd, string, 0))
  assert(vim.loop.fs_close(fd))
end

local res, intervention = parse_file()
write_file('filetypes.lua', res)
-- write_file('intervention.txt', intervention)
