local a = require('plenary/async_lib')
local i = require('plenary.iterators')
local uv = vim.loop
local async, await = a.async, a.await

local fs = {}

-- fully async version of scandir
fs.read_dir = async(function(opts)
  local dir = opts.dir

  local err, uv_dir_t = await(a.uv.fs_opendir(dir))
  local dir_stack = { dir }
  local dir_t_stack = { uv_dir_t }
  -- local dir_stack = { {dir, uv_dir_t} }
  assert(not err, err)

  local run
  run = function()
    local err, res = await(a.uv.fs_readdir(dir_t_stack[#dir_t_stack]))
    assert(not err, err)

    if res == nil then
      local dir_t = table.remove(dir_stack)
      local dir = table.remove(dir_t_stack)
      await(a.uv.fs_closedir(dir_t))
      if #dir_stack == 0 then
        return nil
      else
        return run()
      end
      return nil
    end

    res = res[1]

    if res.type == "directory" then
      local path = dir_stack[#dir_stack][1] .. '/' .. res.name
      local err, dir_t = await(a.uv.fs_opendir(path))
      assert(not err, err)

      table.insert(dir_stack, {res.name, dir_t})
      return res
    end

    return res
  end

  return i.from_fun(run)
end)

local do_it = async(function()
  local res = await(fs.read_dir{ dir = "/home/brian/code" }):tolist()
  -- dump(res)
  dump(res())
  dump(res())
end)

a.run(do_it(), function() print('done') end)

return fs
