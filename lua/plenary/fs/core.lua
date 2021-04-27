local a = require('plenary/async_lib2')
local i = require('plenary.iterators')
local Path = require('plenary.path')

local fs = {}

-- fully async version of scandir
-- it returns an iterator
fs.read_dir = function(opts)
  local dir = opts.dir
  local filter = i.iter(opts.filter or {})
  local depth = 1
  local max_depth = opts.max_depth

  local err, uv_dir_t = a.uv.fs_opendir(dir)
  assert(not err, err)

  local dir_stack = { uv_dir_t }
  local path = Path:new(dir)

  local run
  run = function()
    local err, res = a.uv.fs_readdir(dir_stack[#dir_stack])
    assert(not err, err)

    if res == nil then
      local dir_t = table.remove(dir_stack)
      a.uv.fs_closedir(dir_t)

      if #dir_stack == 0 then
        return nil
      else
        path = Path:new(path:parent())

        return run()
      end
    end

    res = res[1]

    if res.name == nil then
      return run
    elseif filter:find(path) then
      return run()
    elseif opts.hidden ~= true and res.name:sub(1, 1) == '.' then
      return run()
    end

    if res.type == "directory" then
      if max_depth ~= nil and depth > max_depth then
        return res
      end

      depth = depth + 1

      path = path / res.name

      local err, dir_t = a.uv.fs_opendir(path.filename)
      assert(not err, err)

      dir_stack[#dir_stack+1] = dir_t

      return res
    end

    return res
  end

  return i.from_fun(run)
end

local do_it = function()
  local res = fs.read_dir { dir = "/home/brian/code", hidden = false }:tolist()
  dump(res)
  dump(#res)
  -- dump(res())
  -- dump(res())
  -- dump(res())
  -- dump(res())
  -- dump(res())
  -- dump(res())
end

a.run(do_it, function() print('done') end)

return fs
