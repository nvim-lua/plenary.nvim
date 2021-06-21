local a = require('plenary.async.async')
local uv = vim.loop

local M = {}

M.close = a.wrap(uv.close, 4) -- close a handle

-- filesystem operations
local fs_canceller = function(handle)
  assert(uv.cancel(handle) == 0)
  uv.close(handle)
  -- handle
end

M.fs_open = a.wrap(uv.fs_open, 4, fs_canceller)
M.fs_read = a.wrap(uv.fs_read, 4, fs_canceller)
M.fs_close = a.wrap(uv.fs_close, 2, fs_canceller)
M.fs_unlink = a.wrap(uv.fs_unlink, 2, fs_canceller)
M.fs_write = a.wrap(uv.fs_write, 4, fs_canceller)
M.fs_mkdir = a.wrap(uv.fs_mkdir, 3, fs_canceller)
M.fs_mkdtemp = a.wrap(uv.fs_mkdtemp, 2, fs_canceller)
-- 'fs_mkstemp',
M.fs_rmdir = a.wrap(uv.fs_rmdir, 2, fs_canceller)
M.fs_scandir = a.wrap(uv.fs_scandir, 2, fs_canceller)
M.fs_stat = a.wrap(uv.fs_stat, 2, fs_canceller)
M.fs_fstat = a.wrap(uv.fs_fstat, 2, fs_canceller)
M.fs_lstat = a.wrap(uv.fs_lstat, 2, fs_canceller)
M.fs_rename = a.wrap(uv.fs_rename, 3, fs_canceller)
M.fs_fsync = a.wrap(uv.fs_fsync, 2, fs_canceller)
M.fs_fdatasync = a.wrap(uv.fs_fdatasync, 2, fs_canceller)
M.fs_ftruncate = a.wrap(uv.fs_ftruncate, 3, fs_canceller)
M.fs_sendfile = a.wrap(uv.fs_sendfile, 5, fs_canceller)
M.fs_access = a.wrap(uv.fs_access, 3, fs_canceller)
M.fs_chmod = a.wrap(uv.fs_chmod, 3, fs_canceller)
M.fs_fchmod = a.wrap(uv.fs_fchmod, 3, fs_canceller)
M.fs_utime = a.wrap(uv.fs_utime, 4, fs_canceller)
M.fs_futime = a.wrap(uv.fs_futime, 4, fs_canceller)
-- 'fs_lutime',
M.fs_link = a.wrap(uv.fs_link, 3, fs_canceller)
M.fs_symlink = a.wrap(uv.fs_symlink, 4, fs_canceller)
M.fs_readlink = a.wrap(uv.fs_readlink, 2, fs_canceller)
M.fs_realpath = a.wrap(uv.fs_realpath, 2, fs_canceller)
M.fs_chown = a.wrap(uv.fs_chown, 4, fs_canceller)
M.fs_fchown = a.wrap(uv.fs_fchown, 4, fs_canceller)
-- 'fs_lchown',
M.fs_copyfile = a.wrap(uv.fs_copyfile, 4, fs_canceller)
-- add('fs_opendir', 3) -- TODO: fix this one
M.fs_readdir = a.wrap(uv.fs_readdir, 2, fs_canceller)
M.fs_closedir = a.wrap(uv.fs_closedir, 2, fs_canceller)
-- 'fs_statfs',

-- stream
M.shutdown = a.wrap(uv.shutdown, 2)
M.listen = a.wrap(uv.listen, 3)
-- add('read_start', 2) -- do not do this one, the callback is made multiple times
M.write = a.wrap(uv.write, 3)
M.write2 = a.wrap(uv.write2, 4)
M.shutdown = a.wrap(uv.shutdown, 2)

-- tcp
M.tcp_connect = a.wrap(uv.tcp_connect, 4)
-- 'tcp_close_reset',

-- pipe
M.pipe_connect = a.wrap(uv.pipe_connect, 3)

-- udp
M.udp_send = a.wrap(uv.udp_send, 5)
M.udp_recv_start = a.wrap(uv.udp_recv_start, 2)

-- fs event (wip make into async await event)
-- fs poll event (wip make into async await event)

-- dns
M.getaddrinfo = a.wrap(uv.getaddrinfo, 4)
M.getnameinfo = a.wrap(uv.getnameinfo, 2)

return M
