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
--- this is actually slower, but at least doesn't execute in main loop?
local first_bench = async(function()
  local contents = await(read_file(assets_dir .. 'syn.json'))

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
  local contents = await(read_file(assets_dir .. 'syn.json'))

  local lines = vim.split(contents, '\n')

  local start = os.clock()

  for idx, line in ipairs(lines) do
    lines[idx] = string.match(line, 'i')
  end

  print("Elapsed time: ", os.clock() - start)
end)

local third_bench = async(function()
  local contents = await(read_file(assets_dir .. 'syn.json'))

  local lines = vim.split(contents, '\n')

  local start = os.clock()

  local result = await(work.map_async(lines, function(idx, value)
    value = string.match(value, 'i')
    return idx, value
  end))

  print('result amount', #result == #lines)

  print("Elapsed time: ", os.clock() - start)
end)

local fourth_bench = async(function()
  local contents = await(read_file(assets_dir .. 'syn.json'))

  local lines = vim.split(contents, '\n')

  local start = os.clock()

  for idx, line in ipairs(lines) do
    lines[idx] = work.thread({
      func = function(handle, s)
        handle:send(string.match(s, 'i'))
      end,
      args = {line},
    })

    if idx == 10 then
      break
    end
  end

  local result = await_all(lines)

  print('result amount', #result == #lines)

  print("Elapsed time: ", os.clock() - start)
end)

-- a.run(first_bench())
-- a.run(second_bench())
-- a.run(third_bench())
a.run(fourth_bench())
