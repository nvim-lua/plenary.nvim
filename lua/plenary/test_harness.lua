package.loaded['luvjob'] = nil
package.loaded['plenary.test_harness'] = nil

local luvjob = require('luvjob')

local f = require("plenary.functional")
local lu = require("luaunit")
local Path = require("plenary.path")
local win_float = require("plenary.window.float")

local p_debug = vim.fn.getenv("DEBUG_PLENARY")
if p_debug == vim.NIL then
  p_debug = false
end

local log = setmetatable({}, {
  __index = function(_, key)
    return function(...)
      if (key == 'debug') and (not p_debug) then
        return
      end

      print('[', key, ']', ..., "\n")
    end
  end
})

local harness = {}

local function validate_test_type(test_type)
  if test_type ~= 'luaunit' and test_type ~= 'busted' then
    error(
      string.format(
        'Unexpected test_type: %s. Expected luaunit or busted.\n%s',
        test_type,
        debug.traceback()
      )
    )
  end
end


local print_output = function(_, ...)
  for _, v in ipairs({...}) do
    print(v)
  end
end

local nvim_output = function(buf, ...)
  vim.fn.nvim_buf_set_lines(buf, -1, -1, false, {...})
end

function harness:run(test_type, buf, win, ...)
  validate_test_type(test_type)

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

  if test_type == 'luaunit' then
    print("\n")
    print("===== Results ===== ")
    print("\n")
    print("\n")

    lu.LuaUnit.run(...)
  elseif test_type == 'busted' then
    -- Requires people to have called `setup_busted`
  else
    assert(false)
  end

  -- Would not mind having a bit nicer output, but it's fine for now.
  -- lu.LuaUnit.run("--outputtype=tap")

  -- weirdly need to redraw the screen sometimes... oh well
  vim.fn.win_gotoid(win)
  vim.cmd("mode")
  vim.cmd("nnoremap q :q<CR>")
end

function harness:test_directory(test_type, directory, headless)
  validate_test_type(test_type)

  log.debug("Starting...")

  local res = win_float.centered()
  vim.cmd('mode')
  vim.fn.nvim_buf_set_keymap(res.buf, "n", "q", ":q<CR>", {})

  local outputter
  if headless then
    outputter = print_output
  else
    outputter = nvim_output
  end

  local paths = self:_find_files_to_run(directory)
  local jobs = f.map(
    function(p)
      return luvjob:new({
        command = 'nvim',
        args = {
          '--headless',
          '-c',
          string.format(
            'lua require("plenary.test_harness"):_run_path("%s", "%s")',
            test_type, p
          )
        },
        -- Can be turned on to debug
        on_stdout = function(...)
          if p_debug then
            print("STDOUT:", ...)
          end
        end,
        on_stderr = function(...)
          if p_debug then
            print("STDERR:", ...)
          end
        end,
        on_exit = function(j_self, _, _)
          outputter(res.buf, unpack(j_self:result()))
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

  log.debug("...Waiting")
  luvjob.join(unpack(jobs))
  log.debug("Done...")

  if headless then
    vim.cmd('qa!')
  end
end

function harness:_find_files_to_run(directory)
  local finder = luvjob:new({
    command = 'find',
    args = {directory, '-type', 'f', '-name', '*_spec.lua'},
  })

  finder:start()
  finder:wait()

  return f.map(Path.new, finder:result())
end

function harness:_run_path(test_type, directory)
  validate_test_type(test_type)

  local paths = harness:_find_files_to_run(directory)

  local buf = 0
  local win = 0

  for _, p in pairs(paths) do
    print(" ")
    print("Loading Tests For: ", p:absolute(), "\n")

    local ok, _ = pcall(function() dofile(p:absolute()) end)

    if not ok then
      print("Failed to load file")
    end
  end

  harness:run(test_type, buf, win)
  vim.cmd("qa!")

  return paths
end


function harness:setup_busted()
  require('busted.runner')({output='plainTerminal'}, 3)
end

return harness
