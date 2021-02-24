local a = require('plenary.async_lib.async')
local uv = vim.loop

local M = {}

local function add(tbl, name)
  local success, ret = pcall(a.wrap, uv[name])

  if not success then
    error("Failed to add function with name " .. name)
  end

  tbl[name] = ret
end

local fn_names = {
  'close', -- close a handle

  -- filesystem operations
  'fs_open',
  'fs_read',
  'fs_close',
  'fs_unlink',
  'fs_write',
  'fs_mkdir',
  'fs_mkdtemp',
  -- 'fs_mkstemp',
  'fs_rmdir',
  'fs_scandir',
  'fs_stat',
  'fs_fstat',
  'fs_lstat',
  'fs_rename',
  'fs_fsync',
  'fs_fdatasync',
  'fs_ftruncate',
  'fs_sendfile',
  'fs_access',
  'fs_chmod',
  'fs_fchmod',
  'fs_utime',
  'fs_futime',
  -- 'fs_lutime',
  'fs_link',
  'fs_symlink',
  'fs_readlink',
  'fs_realpath',
  'fs_chown',
  'fs_fchown',
  -- 'fs_lchown',
  'fs_copyfile',
  'fs_opendir',
  'fs_readdir',
  'fs_closedir',
  -- 'fs_statfs',

  -- stream
  'shutdown',
  'listen',
  'read_start',
  'write',
  'write2',
  'shutdown',

  -- tcp
  'tcp_connect',
  -- 'tcp_close_reset',

  -- pipe
  'pipe_connect',

  -- udp
  'udp_send',
  'udp_recv_start',

  -- fs event (wip make into async await event)
  -- fs poll event (wip make into async await event)
  
  -- dns
  'getaddrinfo',
  'getnameinfo',
}

for _, fn_name in ipairs(fn_names) do
  add(M, fn_name)
end

return M
