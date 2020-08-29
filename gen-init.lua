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

local command = {
  'luacc',
  '-o', 'init.lua',
  '-i', 'lua/plenary',
}

for _, v in ipairs(all_modules('lua/plenary')) do
  table.insert(command, v)
end

vim.fn.jobwait({vim.fn.jobstart(command)})
