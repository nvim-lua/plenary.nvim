local a = require('plenary/async_lib')
local uv = vim.loop
local async, await = a.async, a.await

local fs = {}

-- fully async version of scandir
fs.read_dir = async(function(dir)
  local err, uv_dir_t = await(a.uv.fs_opendir(dir))
  -- assert(not err, err)
  print(uv_dir_t)
  dump(await(a.uv.fs_readdir(uv_dir_t)))
  -- dump(uv.fs_readdir(uv_dir_t))
  -- dump(uv.fs_readdir(uv_dir_t))
  -- dump(uv.fs_readdir(uv_dir_t))
  -- dump(uv.fs_readdir(uv_dir_t))
  -- dump(uv.fs_readdir(uv_dir_t))
  -- local err, success = await(a.uv.fs_closedir(uv_dir_t))
  -- return entries
end)

a.run(fs.read_dir("/home/brian/code", 3), function(...) dump(...) end)

return fs
