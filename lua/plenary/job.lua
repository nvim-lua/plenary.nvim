local vim = vim
local uv = vim.loop

local log = require('plenary.log')

local Job = {}
Job.__index = Job

local function close_safely(handle)
  if not handle:is_closing() then
    handle:close()
  end
end

local shutdown_factory = function (child)
  return function(code, signal)
    child:shutdown(code, signal)
  end
end


--- Create a new job
--@param o table
--@field o.command string  : Command to run
--@field o.args Array      : List of arguments to pass
--@field o.cwd string      ? Working directory for job
--@field o.env Map         : Environment
--@field o.detach callable : Function to call on detach.
--
--@field o.call_on_lines boolean? Only call callbacks on line.
function Job:new(o)
  local obj = {}

  obj.command = o.command
  obj.args = o.args
  obj.cwd = o.cwd
  obj.env = o.env
  obj.detach = o.detach

  obj._user_on_start = o.on_start
  obj._user_on_stdout = o.on_stdout
  obj._user_on_stderr = o.on_stderr
  obj._user_on_exit = o.on_exit

  obj._additional_on_exit_callbacks = {}

  obj._maximum_results = o.maximum_results

  obj.user_data = {}

  return setmetatable(obj, self)
end

--- Send data to a job.
function Job:send(data)
  self.stdin:write(data)

  -- TODO: I don't remember why I put this.
  -- self.stdin:shutdown()
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
  self.code = code
  self.signal = signal

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

  self.stdin = uv.new_pipe(false)
  self.stdout = uv.new_pipe(false)
  self.stderr = uv.new_pipe(false)

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

-- TODO: Add the ability to have callback called ONLY on complete lines.
--          Remember, to send the last line when you're done though :laugh:
local on_output = function(self, cb)
  if not self.results then
    self.results = {''}
  end

  local results = self.results

  return function(err, data)
    if data == nil then
      if results[#results] == '' then
        table.remove(results, #results)
      end

      return
    end

    local line, start, found_newline
    repeat
      start = string.find(data, "\n") or #data
      found_newline = string.find(data, "\n")

      line = string.sub(data, 1, start)
      data = string.sub(data, start + 1, -1)

      line = line:gsub("\r", "")

      results[#results] = (results[#results] or '') .. line

      if found_newline then
        local result_number = #results

        if cb then
          cb(err, results[result_number], self)
        end

        -- Stop processing if we've surpassed the maximum.
        if self._maximum_results then
          if result_number > self._maximum_results then
            self:shutdown()
            return
          end
        end

        table.insert(results, '')
      end
    until not found_newline

  end
end

function Job:start()
  local options = self:_create_uv_options()

  if self._user_on_start then
    self:_user_on_start()
  end

  self.handle, self.pid = uv.spawn(
    options.command,
    options,
    vim.schedule_wrap(shutdown_factory(self))
  )

  self.stdout:read_start(on_output(self, self._user_on_stdout))
  self.stderr:read_start(on_output(self, self._user_on_stderr))

  return self
end

function Job:sync()
  self:start()
  self:wait()

  return self:result()
end

function Job:result()
  return self.results
end

function Job:pid()
  return self.pid
end

function Job:wait()
  if self.handle == nil then
    vim.api.nvim_err_writeln(vim.inspect(self))
    return
  end

  while not vim.wait(100, function() return not self.handle:is_active() or self.is_shutdown end, 10) do
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

return Job
