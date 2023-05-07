local Path = require "plenary.path"
local Job = require "plenary.job"

local f = require "plenary.functional"
local log = require "plenary.log"
local win_float = require "plenary.window.float"

local headless = require("plenary.nvim_meta").is_headless

local harness = {}

local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match "(.*/)"
end

local print_output = vim.schedule_wrap(function(_, ...)
  for _, v in ipairs { ... } do
    io.stdout:write(tostring(v))
    io.stdout:write "\n"
  end

  vim.cmd [[mode]]
end)

local get_nvim_output = function(job_id)
  return vim.schedule_wrap(function(bufnr, ...)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    for _, v in ipairs { ... } do
      vim.api.nvim_chan_send(job_id, v .. "\r\n")
    end
  end)
end

function harness.test_directory_command(...)
  return harness.test_path_command(...)
end

function harness.test_directory(...)
  return harness.test_path(...)
end

function harness.test_path_command(command)
  local split_string = vim.split(command, " ")
  local path = vim.fn.expand(table.remove(split_string, 1))

  local opts = assert(loadstring("return " .. table.concat(split_string, " ")))()

  return harness.test_path(path, opts)
end

function harness.test_path(path, opts)
  opts = vim.tbl_deep_extend("force", {
    nvim_cmd = vim.v.progpath,
    winopts = { winblend = 3 },
    sequential = false,
    keep_going = true,
    timeout = 50000,
    debug = false,
  }, opts or {})

  local output_compact = opts.output_format == "compact"

  if not output_compact then
    print "Starting..."
  end

  vim.env.PLENARY_TEST_TIMEOUT = opts.timeout

  local res = {}
  if not headless then
    res = win_float.percentage_range_window(0.95, 0.70, opts.winopts)

    res.job_id = vim.api.nvim_open_term(res.bufnr, {})
    vim.api.nvim_buf_set_keymap(res.bufnr, "n", "q", ":q<CR>", {})

    vim.api.nvim_win_set_option(res.win_id, "winhl", "Normal:Normal")
    vim.api.nvim_win_set_option(res.win_id, "conceallevel", 3)
    vim.api.nvim_win_set_option(res.win_id, "concealcursor", "n")

    if res.border_win_id then
      vim.api.nvim_win_set_option(res.border_win_id, "winhl", "Normal:Normal")
    end

    if res.bufnr then
      vim.api.nvim_buf_set_option(res.bufnr, "filetype", "PlenaryTestPopup")
    end
    vim.cmd "mode"
  end

  local outputter = headless and print_output or get_nvim_output(res.job_id)

  local paths = vim.fn.isdirectory(path) == 1 and harness._find_files_to_run(path) or { Path.new(path) }

  local path_len = #paths

  local failure = false

  local run_opts = {
    output_format = opts.output_format or "default",
  }

  local jobs = vim.tbl_map(function(p)
    local args = {
      "--headless",
      "-c",
      string.format('let &runtimepath="%s,".&runtimepath', vim.fn.fnamemodify(script_path(), ":p:h:h:h")),
      "-c",
      string.format('lua require("plenary.busted").run("%s", [[%s]])', p:absolute(), vim.json.encode(run_opts)),
    }

    if opts.minimal ~= nil then
      table.insert(args, "--noplugin")
    elseif opts.minimal_init ~= nil then
      table.insert(args, "--noplugin")

      table.insert(args, "-u")
      table.insert(args, opts.minimal_init)
    end

    local job = Job:new {
      command = opts.nvim_cmd,
      args = args,

      -- Can be turned on to debug
      on_stdout = function(_, data)
        if path_len == 1 then
          outputter(res.bufnr, data)
        end
      end,

      on_stderr = function(_, data)
        if path_len == 1 then
          outputter(res.bufnr, data)
        end
      end,

      on_exit = vim.schedule_wrap(function(j_self, _, _)
        if path_len ~= 1 then
          outputter(res.bufnr, unpack(j_self:stderr_result()))
          outputter(res.bufnr, unpack(j_self:result()))
        end

        vim.cmd "mode"
      end),
    }
    job.nvim_busted_path = p.filename
    return job
  end, paths)

  print ""

  log.debug "Running..."

  for i, j in ipairs(jobs) do
    if not output_compact then
      outputter(res.bufnr, "Scheduling: " .. j.nvim_busted_path)
    end

    j:start()
    if opts.sequential then
      log.debug("... Sequential wait for job number", i)
      if not Job.join(j, opts.timeout) then
        log.debug("... Timed out job number", i)
        failure = true
        pcall(function()
          j.handle:kill(15) -- SIGTERM
        end)
      else
        log.debug("... Completed job number", i, j.code, j.signal)
        failure = failure or j.code ~= 0 or j.signal ~= 0
      end
      if failure and not opts.keep_going then
        break
      end
    end
  end

  -- TODO: Probably want to let people know when we've completed everything.
  if not headless then
    return
  end

  if not opts.sequential then
    table.insert(jobs, opts.timeout)
    log.debug "... Parallel wait"
    Job.join(unpack(jobs))
    log.debug "... Completed jobs"
    table.remove(jobs, table.getn(jobs))
    failure = f.any(function(_, v)
      return v.code ~= 0
    end, jobs)
  end
  vim.wait(100)

  if headless then
    print " \n"

    if failure then
      return vim.cmd "1cq"
    end

    return vim.cmd "0cq"
  end
end

function harness._find_files_to_run(directory)
  local finder = Job:new {
    command = "find",
    args = { directory, "-type", "f", "-name", "*_spec.lua" },
  }

  return vim.tbl_map(Path.new, finder:sync())
end

return harness
