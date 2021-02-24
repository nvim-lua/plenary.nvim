local a = require('plenary.async_lib')
local async = a.async
local work = a.work
local await = a.await
local await_all = a.await_all
local uv = vim.loop

local plenary_init = vim.api.nvim_get_runtime_file('lua/plenary/init.lua', false)[1]
local plenary_dir = vim.fn.fnamemodify(plenary_init, ":h:h:h")
local assets_dir = plenary_dir .. '/' .. 'tests/plenary/async_lib/assets/'

local read_file = async(function(path)
  local err, fd = await(a.uv.fs_open(path, "r", 438))
  assert(not err, err)

  local err, stat = await(a.uv.fs_fstat(fd))
  assert(not err, err)

  local err, data = await(a.uv.fs_read(fd, stat.size, 0))
  assert(not err, err)

  local err = await(a.uv.fs_close(fd))
  assert(not err, err)

  return data
end)

local test = async(function()
  local res = await(work.string.match('abcdefg', 'b..'))
end)

a.run(test())

--- readfile asynchronously, string process IS async using work
local first_bench = async(function()
  local contents = await(read_file(assets_dir .. 'README.md'))

  local lines = vim.split(contents, '\n')

  local start = os.clock()

  for idx, line in ipairs(lines) do
    lines[idx] = work.string.match(line, 'i')
  end

  local results = await_all(lines)

  print("Elapsed time: ", os.clock() - start)
end)

--- readfile asynchronously, string process not async
local second_bench = async(function()
  local contents = await(read_file(assets_dir .. 'README.md'))

  local lines = vim.split(contents, '\n')

  local start = os.clock()

  for idx, line in ipairs(lines) do
    lines[idx] = string.match(line, 'i')
  end

  print("Elapsed time: ", os.clock() - start)
end)

a.run(second_bench())
