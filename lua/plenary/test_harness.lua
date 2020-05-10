package.loaded['luvjob'] = nil
package.loaded['plenary.test_harness'] = nil

local luvjob = require('luvjob')

local f = require("plenary.functional")
local lu = require("plenary.luaunit")
local Path = require("plenary.path")
local win_float = require("plenary.window.float")

local log = setmetatable({}, {
  __index = function(_, key)
    return function(...)
      if key == 'debug' then
        return
      end

      print('[', key, ']', ...)
    end
  end
})

local test_harness = {}
test_harness.__index = lu.__index

function test_harness:run(buf, win, ...)
  if buf == nil then
    buf = vim.fn.nvim_create_buf(false, true)
  end

  if win == nil then
    -- TODO: Could just make win be 0...?
    local opts = win_float.default_opts()
    win = vim.fn.nvim_open_win(buf, true, opts)
  end

  vim.fn.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.fn.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  vim.fn.nvim_buf_set_option(buf, 'swapfile', false)

  lu.LuaUnit.run(...)
  -- Would not mind having a bit nicer output, but it's fine for now.
  -- lu.LuaUnit.run("--outputtype=tap")

  -- weirdly need to redraw the screen sometimes... oh well
  vim.fn.win_gotoid(win)
  vim.cmd("mode")
  vim.cmd("nnoremap q :q<CR>")
end

function test_harness:float()
  local res = win_float.centered()
  local buf = res.buf
  local win = res.win

  test_harness:run(buf, win)
end

function test_harness:test_directory(directory)
  log.debug("Starting...")

  local res = win_float.centered()
  vim.cmd('mode')
  vim.fn.nvim_buf_set_keymap(res.buf, "n", "q", ":q<CR>", {})

  local paths = self:_find_files_to_run(directory)
  local jobs = f.map(
    function(p)
      return luvjob:new({
        command = 'nvim',
        args = {'--headless', '-c', string.format('lua require("plenary.test_harness"):_run_path("%s")', p)},
        on_exit = function(j_self, _, _)
          vim.fn.nvim_buf_set_lines(res.buf, -1, -1, false, j_self:result())
          vim.cmd('mode')
        end
      })
    end,
    paths
  )

  log.debug("Running...")
  for _, j in ipairs(jobs) do
    j:start()
  end

  luvjob.join(unpack(jobs))

  log.debug("Done...")
  -- for _, j in ipairs(jobs) do
  -- end
end

function test_harness:_find_files_to_run(directory)
  local finder = luvjob:new({
    command = 'find',
    args = {directory, '-type', 'f', '-name', '*_spec.lua'},
  })

  finder:start()
  finder:wait()

  return f.map(Path.new, finder:result())
end

function test_harness:_run_path(directory)
  local paths = test_harness:_find_files_to_run(directory)

  local buf = 0
  local win = 0

  for _, p in pairs(paths) do
    print("Loading Tests For: ", p:absolute())
    dofile(p:absolute())
  end

  print("\n")
  print("===== Results ===== ")
  print("\n")
  test_harness:run(buf, win)
  print("\n")

  vim.cmd("qa!")

  return paths
end


return test_harness
