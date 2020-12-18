--[[
--
-- TODO: We should actually write the tests here, these are just examples.
local Job = require('plenary.job')

describe('Job', function()
  it('should_chain_data', function()
    local first_job = Job:new(...)
    local second_job = Job:new(...)

    -- Different options
    first_job:chain(second_job)
    first_job:and_then(second_job)
    first_job:then(second_job)

    Job.chain(first_job, second_job)

    first_job:after(function() ... end)

    -- Different kinds of things
    -- 1. Run one job, then run another (only when finished, possibly w/ the results)
    -- 2. Run one job, when done, run some synchronous code (just some callback, not necessarily a Job)
    -- 3. Pipe stdout of one job, to the next job

    -- Example 1:
    -- I have a job that searches the file system for X
    -- I have another job that determines the git status for X

    -- Example 2:
    -- I have a job that does some file system stuff
    -- I want to prompt the user what to do when it's done
  end)
end)
--]]


local Job = require('plenary.job')

local has_all_executables = function(execs)
  for _, e in ipairs(execs) do
    if vim.fn.executable(e) == 0 then
      return false
    end
  end

  return true
end

describe('Job', function()
  describe('> cat manually >', function()
    it('should split simple stdin', function()
      local results = {}
      local job = Job:new {
        command = 'cat',

        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:start()
      job:send("hello\n")
      job:send("world\n")
      job:shutdown()

      assert.are.same(job:result(), {'hello', 'world'})
      assert.are.same(job:result(), results)
    end)

    it('should allow empty strings', function()
      local results = {}
      local job = Job:new {
        command = 'cat',

        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:start()
      job:send("hello\n")
      job:send("\n")
      job:send("world\n")
      job:send("\n")
      job:shutdown()

      assert.are.same(job:result(), {'hello', '', 'world', ''})
      assert.are.same(job:result(), results)
    end)

    it('should split stdin across newlines', function()
      local results = {}
      local job = Job:new {
        -- writer = "hello\nword\nthis is\ntj",
        command = 'cat',

        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:start()
      job:send("hello\nwor")
      job:send("ld\n")
      job:shutdown()

      assert.are.same(job:result(), {'hello', 'world'})
      assert.are.same(job:result(), results)
    end)

    it('should split stdin across newlines with no ending newline', function()
      local results = {}
      local job = Job:new {
        -- writer = "hello\nword\nthis is\ntj",
        command = 'cat',

        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:start()
      job:send("hello\nwor")
      job:send("ld")
      job:shutdown()

      assert.are.same(job:result(), {'hello', 'world'})
      assert.are.same(job:result(), results)
    end)
  end)

  describe('env', function()
    it('should be possible to set one env variable with an array', function()
      local results = {}
      local job = Job:new {
        command = 'env',
        env = { 'A=100' },
        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:sync()

      assert.are.same(job:result(), { 'A=100' })
      assert.are.same(job:result(), results)
    end)

    it('should be possible to set multiple env variables with an array', function()
      local results = {}
      local job = Job:new {
        command = 'env',
        env = { 'A=100', 'B=test' },
        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:sync()

      assert.are.same(job:result(), { 'A=100', 'B=test' })
      assert.are.same(job:result(), results)
    end)

    it('should be possible to set one env variable with a map', function()
      local results = {}
      local job = Job:new {
        command = 'env',
        env = { 'A=100' },
        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:sync()

      assert.are.same(job:result(), { 'A=100' })
      assert.are.same(job:result(), results)
    end)

    it('should be possible to set one env variable with spaces', function()
      local results = {}
      local job = Job:new {
        command = 'env',
        env = { 'A=This is a long env var' },
        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:sync()

      assert.are.same(job:result(), { 'A=This is a long env var' })
      assert.are.same(job:result(), results)
    end)

    it('should be possible to set multiple env variables with a map', function()
      local results = {}
      local job = Job:new {
        command = 'env',
        env = { ['A'] = 100, ['B'] = 'test' },
        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:sync()

      local expected = { 'A=100', 'B=test' }
      local found = { false, false }
      for k, v in ipairs(job:result()) do
        for _, w in ipairs(expected) do
          if v == w then found[k] = true end
        end
      end

      assert.are.same({ true, true }, found)
      assert.are.same(job:result(), results)
    end)

    it('should be possible to set multiple env variables with both, array and map', function()
      local results = {}
      local job = Job:new {
        command = 'env',
        env = { ['A'] = 100, 'B=test' },
        on_stdout = function(_, data)
          table.insert(results, data)
        end,
      }

      job:sync()

      local expected = { 'A=100', 'B=test' }
      local found = { false, false }
      for k, v in ipairs(job:result()) do
        for _, w in ipairs(expected) do
          if v == w then found[k] = true end
        end
      end

      assert.are.same({ true, true }, found)
      assert.are.same(job:result(), results)
    end)
  end)

  describe('> simple ls >', function()
    it('should match systemlist', function()
      local ls_results = vim.fn.systemlist('ls -l')

      local job = Job:new {
        command = 'ls',
        args = {'-l'},
      }

      job:sync()
      assert.are.same(job:result(), ls_results)
    end)

    it('should match larger systemlist', function()
      local results = vim.fn.systemlist('find')
      local stdout_results = {}

      local job = Job:new {
        command = 'find',

        on_stdout = function(_, line) table.insert(stdout_results, line) end
      }

      job:sync()
      assert.are.same(job:result(), results)
      assert.are.same(job:result(), stdout_results)
    end)

    it('should not timeout when completing fast jobs', function()
      local start = vim.loop.hrtime()

      local job = Job:new { command = 'ls' }

      job:sync()

      assert((vim.loop.hrtime() - start) / 1e9 < 1, "Should not take one second to complete")
    end)
  end)

  describe('.writer', function()
    pending('should allow using things like fzf', function()
      if not has_all_executables { 'fzf', 'fdfind' } then
        return
      end

      local stdout_results = {}

      local fzf = Job:new {
        writer = Job:new {
          command = 'fdfind',
          cwd = vim.fn.expand("~/plugins/plenary.nvim/"),
        },

        command = 'fzf';
        args = {'--filter', 'job.lua'};

        cwd = vim.fn.expand("~/plugins/plenary.nvim/"),

        on_stdout = function(_, line) table.insert(stdout_results, line) end
      }

      local results = fzf:sync()
      assert.are.same(results, stdout_results)

      -- 'job.lua' should be the best file from fzf.
      --    So make sure we're processing correctly.
      assert.are.same('lua/plenary/job.lua', results[1])
    end)

    it('should work with a table', function()
      if not has_all_executables { 'fzf' } then
        return
      end

      local stdout_results = {}

      local fzf = Job:new {
        writer = {"hello", "world", "job.lua"},

        command = 'fzf';
        args = {'--filter', 'job.lua'};

        on_stdout = function(_, line) table.insert(stdout_results, line) end
      }

      local results = fzf:sync()
      assert.are.same(results, stdout_results)

      -- 'job.lua' should be the best file from fzf.
      --    So make sure we're processing correctly.
      assert.are.same('job.lua', results[1])
      assert.are.same(1, #results)
    end)

    it('should work with a string', function()
      if not has_all_executables { 'fzf' } then
        return
      end

      local stdout_results = {}

      local fzf = Job:new {
        writer = "hello\nworld\njob.lua",

        command = 'fzf';
        args = {'--filter', 'job.lua'};

        on_stdout = function(_, line) table.insert(stdout_results, line) end
      }

      local results = fzf:sync()
      assert.are.same(results, stdout_results)

      -- 'job.lua' should be the best file from fzf.
      --    So make sure we're processing correctly.
      assert.are.same('job.lua', results[1])
      assert.are.same(1, #results)
    end)

    it('should work with a pipe', function()
      if not has_all_executables { 'fzf' } then
        return
      end

      local input_pipe = vim.loop.new_pipe(false)

      local stdout_results = {}
      local fzf = Job:new {
        writer = input_pipe,

        command = 'fzf';
        args = {'--filter', 'job.lua'};

        on_stdout = function(_, line) table.insert(stdout_results, line) end
      }

      fzf:start()

      input_pipe:write("hello\n")
      input_pipe:write("world\n")
      input_pipe:write("job.lua\n")
      input_pipe:close()

      fzf:shutdown()

      local results = fzf:result()
      assert.are.same(results, stdout_results)

      -- 'job.lua' should be the best file from fzf.
      --    So make sure we're processing correctly.
      assert.are.same('job.lua', results[1])
      assert.are.same(1, #results)
    end)

    it('should work with a pipe, but no final newline', function()
      if not has_all_executables { 'fzf' } then
        return
      end

      local input_pipe = vim.loop.new_pipe(false)

      local stdout_results = {}
      local fzf = Job:new {
        writer = input_pipe,

        command = 'fzf';
        args = {'--filter', 'job.lua'};

        on_stdout = function(_, line) table.insert(stdout_results, line) end
      }

      fzf:start()

      input_pipe:write("hello\n")
      input_pipe:write("world\n")
      input_pipe:write("job.lua")
      input_pipe:close()

      fzf:shutdown()

      local results = fzf:result()
      assert.are.same(results, stdout_results)

      -- 'job.lua' should be the best file from fzf.
      --    So make sure we're processing correctly.
      assert.are.same('job.lua', results[1])
      assert.are.same(1, #results)
    end)
  end)

  describe(':wait()', function()
    it('should respect timeout', function()
      local j = Job:new {
        command = "sleep",
        args = {"10"}
      }

      local ok = pcall(j.sync, j, 500)
      assert(not ok, "Job should fail")
    end)
  end)


  describe('enable_.*', function()
    it('should not add things to results when disabled', function()
      local job = Job:new {
        command = 'ls',
        args = {'-l'},

        enable_recording = false
      }

      local res = job:sync()
      assert(res == nil, 'No results should exist')
      assert(job._stdout_results == nil, 'No result table')
    end)

    it('should not call callbacks when disabled', function()
      local was_called = false
      local job = Job:new {
        command = 'ls',
        args = {'-l'},

        enable_handlers = false,

        on_stdout = function() was_called = true end
      }

      job:sync()
      assert(not was_called, "Should not be called.")
      assert(job._stdout_results == nil, 'No result table')
    end)
  end)

  describe('enable_.*', function()
    it('should not add things to results when disabled', function()
      local job = Job:new {
        command = 'ls',
        args = {'-l'},

        enable_recording = false
      }

      local res = job:sync()
      assert(res == nil, 'No results should exist')
      assert(job._stdout_results == nil, 'No result table')
    end)

    it('should not call callbacks when disbaled', function()
      local was_called = false
      local job = Job:new {
        command = 'ls',
        args = {'-l'},

        enable_handlers = false,

        on_stdout = function() was_called = true end
      }

      job:sync()
      assert(not was_called, "Should not be called.")
      assert(job._stdout_results == nil, 'No result table')
    end)
  end)

  describe('validation', function()
    it('requires options', function()
      local ok = pcall(Job.new, { command = 'ls' })
      assert(not ok, 'Requires options')
    end)

    it('requires command', function()
      local ok = pcall(Job.new, Job, { cmd = 'ls' })
      assert(not ok, 'Requires command')
    end)

    it('will not spawn jobs with invalid commands', function()
      local job = Job:new { command = 'dasowlwl' }

      local ok = pcall(job.sync, job)
      assert(not ok, "Should not allow invalid executables")
    end)
  end)

  describe('on_exit', function()
    it('should only be called once for wait', function()
      local count = 0

      local job = Job:new{
        command = "ls",
        on_exit = function(...)
          count = count + 1
        end,
      }
      job:start()
      job:wait()

      assert.are.same(count, 1)
    end)

    it('should only be called once for shutdown', function()
      local count = 0

      local job = Job:new{
        command = "ls",
        on_exit = function(...)
          count = count + 1
        end,
      }
      job:start()
      job:shutdown()

      assert.are.same(count, 1)
    end)
  end)
end)
