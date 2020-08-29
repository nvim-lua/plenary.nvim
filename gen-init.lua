local function all_modules(dir)
  local files_and_dirs =
    vim.tbl_filter(
      function(x) return x ~= "" end,
      vim.split(io.popen('ls ' .. dir):read('a'), '\n'))
  local ret = {}

  for _, v in ipairs(files_and_dirs) do
    if not v:find('%.lua') then
      for _, v in ipairs(all_modules(dir .. '/' .. v)) do
        table.insert(ret, (v:gsub('%.lua', '')))
      end
    else
      table.insert(ret, ((dir .. '/' .. v):gsub('%.lua', '')))
    end
  end

  return vim.tbl_map(function(x) return (x:gsub('%/', '%.')) end, ret)
end

vim.api.nvim_command('cd lua/')
local luacc_lua_path = vim.fn.input('Path to luacc.lua: ')
local command = {
  'lua',
  luacc_lua_path,
  '-o', 'init.lua',
  '-i', 'plenary/',
  '-i', 'plenary/lsp',
  '-i', 'plenary/window',
  '-i', 'plenary/neorocks',
  'plenary.init'
}

local modules = vim.tbl_filter(function(x) return x ~= 'plenary.init' end, all_modules('plenary'))

for _, v in ipairs(modules) do
  table.insert(command, (v:gsub('%.init', '')))
end

vim.fn.jobwait(
  {vim.fn.jobstart(command, {
      on_stderr = function(_, d, _)
        print(vim.inspect(d))
      end;
  })}
)

vim.api.nvim_command('!mv init.lua ../init.lua')
vim.api.nvim_command('cd ../')
