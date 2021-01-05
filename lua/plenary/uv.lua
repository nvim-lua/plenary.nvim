--- uv.lua
--- helpers for libuv embedded in neovim
--- NOTE: all multithreaded functions can only except arguments of type nil, boolean, number, string, or userdata
--- giving the wrong arguments will CRASH NEOVIM

local M = {}

--- schedules callback to be executed asynchronously.
--- You can pass in argumnents to the callback with the vararg.
--- Mirrors `vim.schedule`
--- NOTE: the vararg can only except arguments of type nil, boolean, number, string, or userdata
--- giving the wrong arguments will CRASH NEOVIM
function M.async(f, ...)
  local handle
  handle = vim.loop.new_async(function(...)
    f(...)
    handle:close()
  end)
  handle:send(...)
end

--- Wraps a function to make it asynchronous. This will return a new wrapped function.
--- The new function has the same arguments as the old function.
--- NOTE: the vararg can only except arguments of type nil, boolean, number, string, or userdata
--- giving the wrong arguments will CRASH NEOVIM
function M.async_wrap(f)
  return function(...)
    local handle
    handle = vim.loop.new_async(function(...)
      f(...)
      handle:close()
    end)
    handle:send(...)
  end
end

return M
