local a = require('plenary/async_lib2')
local i = require('plenary.iterators')
local Path = require('plenary.path')
local uv = vim.loop
local async, await = a.async, a.await

local fs = {}

-- fully async version of scandir
fs.read_dir = function(opts)
  local dir = opts.dir

  local err, uv_dir_t = a.uv.fs_opendir(dir)
  assert(not err, err)

  local dir_stack = { uv_dir_t }
  local path = Path:new(dir)

  local run
  run = function()
    local err, res = a.uv.fs_readdir(dir_stack[#dir_stack])
    assert(not err, err)

    if res == nil then
      path = Path:new(path:parent())

      local dir_t = table.remove(dir_stack)
      a.uv.fs_closedir(dir_t)

      if #dir_stack == 0 then
        return nil
      else
        return run()
      end
      return nil
    end

    res = res[1]

    if res.type == "directory" then
      path = path / res.name

      local err, dir_t = a.uv.fs_opendir(path.filename)
      assert(not err, err)

      table.insert(dir_stack, dir_t)

      return res
    end

    return res
  end

  return i.from_fun(run)
end

local do_it = function()
  local res = fs.read_dir{ dir = "/home/brian/code" }:tolist()
  dump(res)
  -- dump(res())
  -- dump(res())
  -- dump(res())
  -- dump(res())
  -- dump(res())
  -- dump(res())
end

a.run(do_it, function() print('done') end)

return fs
