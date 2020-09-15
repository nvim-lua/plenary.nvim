local vim = vim
local uv = vim.loop

local functional = require('plenary.functional')

local Job = {}
Job.__index = Job

local function close_safely(handle)
  if not handle then
    return
  end

  if not handle:is_closing() then
    handle:close()
  end
end

local function yield_forever()
  while true do
    coroutine.yield()
  end
end


local start_shutdown_check = function(child, options, code, signal)
  uv.check_start(child._shutdown_check, function()
    -- Wait until all the pipes are closing.
    for _, pipe in ipairs({options.stdin, options.stdout, options.stderr}) do
      if pipe and not uv.is_closing(pipe) then
        return
      end
    end

    uv.check_stop(child._shutdown_check)

    child:_shutdown(code, signal)
  end)
end

local shutdown_factory = function (child, options)
  return function(code, signal)
    if uv.is_closing(child._shutdown_check) then
      return child:shutdown(code, signal)
    else
      start_shutdown_check(child, options, code, signal)
    end
  end
end

---@class Array
--- Numeric table

---@class Map
--- Map-like table


--- Create a new job
---@class Job
---@param o table
---@field o.command string          : Command to run
---@field o.args Array              : List of arguments to pass
---@field o.cwd string              : Working directory for job
---@field o.env Map                 : Environment
---@field o.detach function         : Function to call on detach.
---@field o.enable_handlers boolean : If set to false, disables all callbacks associated with output
---@field o.on_start function       : Run when starting job
---@field o.on_stdout function      : (error: string, data: string, self? Job)
---@field o.on_stderr function      : (error: string, data: string, self? Job)
---@field o.on_exit function        : (self, code: number, signal: number)
---@field o.maximum_results number  : stop processing results after this number
---@field o.writer Job|table|string : Job that writes to stdin of this job.
function Job:new(o)
  if not o then
    error(debug.traceback("Options are required for Job:new"))
  end

  local obj = {}

  obj.command = o.command
  obj.args = o.args
  obj.cwd = o.cwd and vim.fn.expand(o.cwd)
  obj.env = o.env
  obj.detach = o.detach

  obj.enable_handlers = functional.if_nil(o.enable_handlers, true, o.enable_handlers)

  obj._user_on_start = o.on_start
  obj._user_on_stdout = o.on_stdout
  obj._user_on_stderr = o.on_stderr
  obj._user_on_exit = o.on_exit

  obj._additional_on_exit_callbacks = {}

  obj._maximum_results = o.maximum_results

  obj.user_data = {}

  obj.writer = o.writer

  self._reset(obj)

  return setmetatable(obj, self)
end

function Job:_reset()
  self.is_shutdown = nil

  if self._shutdown_check
      and uv.is_active(self._shutdown_check)
      and not uv.is_closing(self._shutdown_check) then
    vim.api.nvim_err_writeln(debug.traceback("We may be memory leaking here. Please report to TJ."))
  end
  self._shutdown_check = uv.new_check()

  self._stdout_reader = nil
  self._stdout_results = {}

  self._stderr_reader = nil
  self._stderr_results = {}
end

--- Stop a job and close all handles
function Job:_stop()
  close_safely(self.stdin)
  close_safely(self.stderr)
  close_safely(self.stdout)
  close_safely(self.handle)
end

--- Shutdown a job.
function Job:shutdown(code, signal)
  if not uv.is_active(self._shutdown_check) then
    start_shutdown_check(self, self, code, signal)

    -- TODO: This seems a bit questionable, but I'm basically waiting for a better `uv.run`.
    --          I will have to investigate a bit more as time goes on.
    vim.wait(10, function()
      uv.run("nowait")
      return uv.is_closing(self._shutdown_check)
    end, 1)

    -- vim.schedule_wrap(function() self:_stop() end)()
  end

  self:_shutdown(code, signal)
end

function Job:_shutdown(code, signal)
  self.code = code
  self.signal = signal

  if self._stdout_reader then
    self._stdout_reader(nil, nil, true)
  end

  if self._stderr_reader then
    self._stderr_reader(nil, nil, true)
  end

  if self._user_on_exit then
    self:_user_on_exit(code, signal)
  end

  for _, v in ipairs(self._additional_on_exit_callbacks) do
    v(self, code, signal)
  end

  self.stdout:read_stop()
  self.stderr:read_stop()

  self:_stop()

  self.is_shutdown = true
end

function Job:_create_uv_options()
  local options = {}

  options.command = self.command
  options.args = self.args
  options.stdio = {
    self.stdin,
    self.stdout,
    self.stderr
  }

  if self.cwd then
    options.cwd = self.cwd
  end

  if self.env then
    options.env = self.env
  end

  if self.detach then
    options.detach = self.detach
  end

  return options
end

local on_output = function(self, results, cb)
  -- cb = cb or function() end

  return coroutine.wrap(function(err, data, is_complete)
    local result_index = 1

    local line, start, found_newline

    -- We repeat forever as a coroutine so that we can keep calling this.
    while true do
      if data then
        local processed_index = 1
        local data_length = #data + 1

        repeat
          start = string.find(data, "\n", processed_index, true) or data_length
          line = string.sub(data, processed_index, start - 1)
          found_newline = start ~= data_length

          -- Concat to last line if there was something there already.
          --    This happens when "data" is broken into chunks and sometimes
          --    the content is sent without any newlines.
          if results[result_index] then
            results[result_index] = results[result_index] .. line

          -- Only put in a new line when we actually have new data to split.
          --    This is generally only false when we do end with a new line.
          --    It prevents putting in a "" to the end of the results.
          elseif start ~= processed_index or found_newline then
            results[result_index] = line

          -- Otherwise, we don't need to do anything.
          end

          if found_newline then
            if not results[result_index] then
              vim.api.nvim_err_writeln(
                "Broken data thing due to: "
                .. tostring(results[result_index])
                .. " "
                .. tostring(data))

              return
            end

            if cb then
              cb(err, results[result_index], self)
            end

            -- Stop processing if we've surpassed the maximum.
            if self._maximum_results then
              if result_index > self._maximum_results then
                -- Shutdown once we get the chance.
                --  Can't call it here, because we'll just keep calling ourselves.
                vim.schedule(function()
                  self:shutdown()
                end)

                -- Make this function do nothing.
                yield_forever()
              end
            end

            result_index = result_index + 1
          end

          processed_index = start + 1
        until not found_newline
      end

      if cb and is_complete and not found_newline then
        cb(err, results[result_index], self)
      end

      if data == nil then
        yield_forever()
      end

      err, data, is_complete = coroutine.yield()
    end
  end)
end

--- Stop previous execution and add new pipes.
--- Also regenerates pipes of writer.
function Job:_prepare_pipes()
  self:_stop()

  if self.writer then
    if Job.is_job(self.writer) then
      self.writer:_prepare_pipes()
    end
  end

  self.stdin = (self.writer and self.writer.stdout) or uv.new_pipe(false)
  self.stdout = uv.new_pipe(false)
  self.stderr = uv.new_pipe(false)
end

--- Execute job. Should be called only after preprocessing is done.
function Job:_execute()
  self:_reset()

  local options = self:_create_uv_options()

  if self._user_on_start then
    self:_user_on_start()
  end

  self.handle, self.pid = uv.spawn(
    options.command,
    options,
    shutdown_factory(self, options)
  )

  if self.enable_handlers then
    self._stdout_reader = on_output(self, self._stdout_results, self._user_on_stdout)
    self.stdout:read_start(self._stdout_reader)

    self._stderr_reader = on_output(self, self._stderr_results, self._user_on_stderr)
    self.stderr:read_start(self._stderr_reader)
  else
    self.stdout:read_start()
    self.stderr:read_start()
  end

  if self.writer then
    if Job.is_job(self.writer) then
      self.writer:_execute()
    elseif type(self.writer) == 'table' and vim.tbl_islist(self.writer) then
      for _, v in ipairs(self.writer) do
        self.stdin:write(v .. '\n')
      end
      self.stdin:close()
    elseif type(self.writer) == 'string' then
      self.stdin:write(self.writer)
      self.stdin:close()
    else
      error('Unknown self.writer: ' .. vim.inspect(self.writer))
    end
  end

  return self
end

function Job:start()
  self:_prepare_pipes()
  self:_execute()
end

function Job:sync(timeout, wait_interval)
  self:start()
  self:wait(timeout, wait_interval)

  return self:result()
end

function Job:result()
  return self._stdout_results
end

function Job:stdder_result()
  return self._stderr_results
end


function Job:pid()
  return self.pid
end

function Job:wait(timeout, wait_interval)
  timeout = timeout or 5000
  wait_interval = wait_interval or 10

  if self.handle == nil then
    vim.api.nvim_err_writeln(vim.inspect(self))
    return
  end

  -- Wait five seconds, or until timeout.
  local wait_result = vim.wait(timeout, function()
    if self.is_shutdown then
      assert(self.handle:is_closing(), "Job must be shutdown if it's closing")
    end

    return self.is_shutdown
  end, wait_interval)

  if not wait_result then
    error(string.format(
      "'%s %s' was unable to complete in %s ms",
      self.command,
      table.concat(self.args or {}, " "),
      timeout
    ))
  end

  return self
end

function Job:co_wait(wait_time)
  wait_time = wait_time or 5

  if self.handle == nil then
    vim.api.nvim_err_writeln(vim.inspect(self))
    return
  end

  while not vim.wait(wait_time, function() return self.is_shutdown end) do
    coroutine.yield()
  end

  return self
end

--- Wait for all jobs to complete
function Job.join(...)
  local jobs_to_wait = {...}

  while true do
    if #jobs_to_wait == 0 then
      break
    end

    local current_job = jobs_to_wait[1]
    if current_job.is_shutdown then
      table.remove(jobs_to_wait, 1)
    end

    -- vim.cmd.sleep(10)
    vim.cmd("sleep 100m")
  end
end

local _request_id = 0
local _request_status = {}

function Job.chain(...)
  _request_id = _request_id + 1
  _request_status[_request_id] = false

  local jobs = {...}

  for index, job in ipairs(jobs) do
    if index ~= 1 then
      local prev_job = jobs[index - 1]
      local original_on_exit = prev_job._user_on_exit
      prev_job._user_on_exit = function(self, err, data)
        if original_on_exit then
          original_on_exit(self, err, data)
        end

        job:start()
      end
    end
  end

  local last_on_exit = jobs[#jobs]._user_on_exit
  jobs[#jobs]._user_on_exit = function(self, err, data)
    if last_on_exit then
      last_on_exit(self, err, data)
    end

    _request_status[_request_id] = true
  end

  jobs[1]:start()

  return _request_id
end

function Job.chain_status(id)
  return _request_status[id]
end

function Job.is_job(item)
  if type(item) ~= 'table' then
    return false
  end

  return getmetatable(item) == Job
end

function Job:add_on_exit_callback(cb)
  table.insert(self._additional_on_exit_callbacks, cb)
end

--- Send data to a job.
function Job:send(data)
  if not self.stdin then
    error("job has no 'stdin'. Have you run `job:start()` yet?")
  end

  self.stdin:write(data)
end

return Job
