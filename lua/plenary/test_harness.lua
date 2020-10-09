local lu = require("luaunit")

local Path = require("plenary.path")
local Job = require("plenary.job")

local f = require("plenary.functional")
local log = require("plenary.log")
local win_float = require("plenary.window.float")

local headless = require("plenary.nvim_meta").is_headless

local harness = {}

local p_debug = false

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

local nvim_output = vim.schedule_wrap(function(bufnr, ...)
  for _, v in ipairs({...}) do
    v = v:gsub("\n", ""):gsub("\r", "")
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {v})
  end
end)

function harness:run(test_type, bufnr, win_id, ...)
  validate_test_type(test_type)

  if bufnr == nil then
    bufnr = vim.fn.nvim_create_buf(false, true)
  end

  if win_id == nil then
    -- TODO: Could just make win be 0...?
    -- local opts = win_float.default_opts()
    -- win_id = vim.fn.nvim_open_win(bufnr, true, opts)
    local range_win_options = win_float.percentage_range_window(0.5, 0.70)
    win_id = range_win_options.win_id
  end

  vim.fn.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.fn.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')
  vim.fn.nvim_buf_set_option(bufnr, 'swapfile', false)

  if test_type == 'luaunit' then
    print("\n")
    print("===== Results ===== ")
    print("\n")
    print("\n")

    local luaunit_result = lu.LuaUnit.run(...)
    if headless and luaunit_result ~= 0 then
      os.exit(luaunit_result)
    end

  elseif test_type == 'busted' then
    -- Requires people to have called `setup_busted`
  else
    assert(false)
  end

  -- Would not mind having a bit nicer output, but it's fine for now.
  -- lu.LuaUnit.run("--outputtype=tap")

  -- weirdly need to redraw the screen sometimes... oh well
  vim.fn.win_gotoid(win_id)
  vim.cmd("mode")
  vim.cmd("nnoremap q :q<CR>")
end

function harness:test_directory(test_type, directory)
  validate_test_type(test_type)

  log.info("Starting...")
  if test_type == 'busted' then
    -- Only need to make sure penlight/lfs is available, since we have slightly different busted
    require('plenary.neorocks').ensure_installed('luafilesystem', 'lfs', true)
    require('plenary.neorocks').ensure_installed('penlight', 'pl', true)
  end

  local res = win_float.percentage_range_window(0.95, 0.70, {winblend = 3})

  vim.api.nvim_buf_set_keymap(res.bufnr, "n", "q", ":q<CR>", {})
  vim.api.nvim_buf_set_option(res.bufnr, 'filetype', 'terminal')

  vim.api.nvim_win_set_option(res.win_id, 'winhl', 'Normal:Normal')
  vim.api.nvim_win_set_option(res.win_id, 'conceallevel', 3)
  vim.api.nvim_win_set_option(res.win_id, 'concealcursor', 'n')

  if res.border_win_id then
    vim.api.nvim_win_set_option(res.border_win_id, 'winhl', 'Normal:Normal')
  end
  vim.cmd('mode')

  local outputter
  if headless then
    outputter = print_output
  else
    outputter = nvim_output
  end

  local paths = self:_find_files_to_run(directory)
  local jobs = f.map(
    function(p)
      return Job:new({
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
        on_stdout = function(_, data)
          data = data:gsub("\n", ""):gsub("\r", "")
          -- outputter(res.bufnr, data)
        end,
        on_stderr = function(_, data)
          data = data:gsub("\n", ""):gsub("\r", "")
          -- outputter(res.bufnr, data)
        end,

        on_exit = vim.schedule_wrap(function(j_self, _, _)
          outputter(res.bufnr, unpack(j_self:stderr_result()))
          outputter(res.bufnr, unpack(j_self:result()))
          vim.cmd('mode')
        end)
      })
    end,
    paths
  )

  log.debug("Running...")
  for _, j in ipairs(jobs) do
    j:start()
  end

  log.debug("...Waiting")
  Job.join(unpack(jobs))
  vim.wait(100)
  log.debug("Done...")

  if headless then
    if f.any(function(_, v)
      return v.code ~= 0
    end, jobs) then
      os.exit(1)
    end

    os.exit(0)
    -- vim.cmd('qa!')
  end
end

function harness:_find_files_to_run(directory)
  local finder = Job:new({
    command = 'find',
    args = {directory, '-type', 'f', '-name', '*_spec.lua'},
  })

  return f.map(Path.new, finder:sync())
end

function harness:_run_path(test_type, directory)
  validate_test_type(test_type)

  local paths = harness:_find_files_to_run(directory)

  local bufnr = 0
  local win_id = 0

  for _, p in pairs(paths) do
    print(" ")
    print("Loading Tests For: ", p:absolute(), "\n")

    dofile(p:absolute())
    -- local ok, _ = pcall(function() dofile(p:absolute()) end)

    -- if not ok then
    --   print("Failed to load file")
    -- end
  end

  harness:run(test_type, bufnr, win_id)
  vim.cmd("qa!")

  return paths
end


function harness:setup_busted()
  if not pcall(require, 'lfs') then
    vim.api.nvim_err_writeln("Lua Filesystem (lfs) is required.")
    return
  end

  if not pcall(require, 'pl') then
    vim.api.nvim_err_writeln("Penlight (pl) is required.")
    return
  end

  require('busted.runner')({output='gtest'}, 3)
end

return harness
