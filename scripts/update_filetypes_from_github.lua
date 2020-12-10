local lyaml = require('lyaml')

local Path = require('plenary.path')
local curl = require('plenary.curl')

local write_file = function(path, string)
  local fd = assert(vim.loop.fs_open(path, "w", 438))
  assert(vim.loop.fs_write(fd, string, 0))
  assert(vim.loop.fs_close(fd))
end

if not Path:new("build/languages.yml"):exists() then
  local languages_yml = curl.get('https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml').body
  write_file("build/languages.yml", languages_yml)
end

local parse_file = function()
  local yml_string = Path:new("build/languages.yml"):read()
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
      table.insert(intervention, vim.inspect(v))
    end
  end

  return 'return ' .. vim.inspect(output), vim.fn.join(intervention, '\n')
end

local res, intervention = parse_file()
P(intervention)
write_file('./data/plenary/filetypes/base.lua', res)
-- write_file('intervention.txt', intervention)
