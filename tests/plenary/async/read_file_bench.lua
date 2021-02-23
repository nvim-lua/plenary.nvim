local a = require('plenary.async')
local uv = vim.loop

local plenary_init = vim.api.nvim_get_runtime_file('lua/plenary/init.lua', false)[1]
local plenary_dir = vim.fn.fnamemodify(plenary_init, ":h:h:h")
local assets_dir = plenary_dir .. '/' .. 'tests/plenary/async/assets/'

local read_file = a.sync(function(path)
  local err, fd = a.wait(a.uv.fs_open(path, "r", 438))
  assert(not err, err)

  local err, stat = a.wait(a.uv.fs_fstat(fd))
  assert(not err, err)

  local err, data = a.wait(a.uv.fs_read(fd, stat.size, 0))
  assert(not err, err)

  local err = a.wait(a.uv.fs_close(fd))
  assert(not err, err)
end)

local read_file_other = function(path, callback)
  uv.fs_open(path, "r", 438, function(err, fd)
    assert(not err, err)
    uv.fs_fstat(fd, function(err, stat)
      assert(not err, err)
      uv.fs_read(fd, stat.size, 0, function(err, data)
        assert(not err, err)
        uv.fs_close(fd, function(err)
          assert(not err, err)
          return callback(data)
        end)
      end)
    end)
  end)
end

local first_bench = a.sync(function()

  local futures = {}

  local start = os.clock()

  for i = 1, 200 do futures[i] = read_file(assets_dir .. 'README.md') end

  a.wait_all(futures)

  print("Elapsed time: ", os.clock() - start)
end)

local second_bench = function()
  local results = {}

  local start = os.clock()

  for i = 1, 200 do
    read_file_other(assets_dir .. 'README.md', function(data)
      results[i] = data
      if #results == 100 then
        print("Elapsed time: ", os.clock() - start)
      end
    end)
  end
end

-- first_bench()()

-- second_bench()
