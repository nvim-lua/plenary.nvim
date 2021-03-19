local a = require("plenary.async_lib")
local async, await, await_all = a.async, a.await, a.await_all
local Condvar = a.utils.Condvar
local channel = a.utils.channel
local uv = vim.loop

local Output = {}
Output.__index = Output

function Output.from_handle(handle)
  return setmetatable(handle, Output)
end

function Output:stdout_lines()
  return vim.split(self.stdout, '\n', true)
end

function Output:stderr_lines()
  return vim.split(self.stderr, '\n', true)
end

local Job = {}
Job.__index = Job

function Job.new(opts)
  local self = setmetatable({}, Job)

  self.dead = false
  self.opts = opts

  self:create_control_flow()
  self:create_pipes()
  self:create_uv_options()

  return self
end

function Job:create_control_flow()
  self.exit_tx, self.exit_rx = channel.oneshot()
  self.stdout_eof_tx, self.stdout_eof_rx = channel.oneshot()
  self.stderr_eof_tx, self.stderr_eof_rx = channel.oneshot()

  self.stdout_data_condvar = Condvar.new()
  self.stderr_data_condvar = Condvar.new()
end

function Job:create_pipes()
  self.stdout = self.opts.stdout or uv.new_pipe(false)
  self.stderr = self.opts.stderr or uv.new_pipe(false)

  if self.opts.writer then
    self.stdin = self.opts.writer.stdout
  else
    self.stdin = self.opts.stdin or uv.new_pipe(false)
  end
end

function Job:create_uv_options()
  local uv_opts = {}
  uv_opts.args = {}

  for i, arg in ipairs(self.opts) do
    if i == 1 then
      uv_opts.command = arg
    else
      uv_opts.args[i - 1] = arg
    end
  end

  uv_opts.stdio = { self.stdin, self.stdout, self.stderr }

  uv_opts.cwd = self.opts.cwd
  uv_opts.env = self.opts.env

  self.uv_opts = uv_opts
end

function Job:check_dead()
  if self.dead then
    error("The job is dead")
  end
end

Job.wait_eof = async(function(self)
  await_all {
    self.stdout_eof_rx(),
    self.stderr_eof_rx(),
    self.exit_rx(),
  }
end)

Job.close_everything = async(function(self)
  local close = a.uv.close

  await_all {
    close(self.stdout),
    close(self.stderr),
    close(self.stdin),
    close(self.process_handle),
  }
end)

--- create a handle to a job
local function new_handle(job)
  local self = {stdout = "", stderr = ""}

  self.write = async(function(self, stuff)
    await(a.uv.write(job.stdin, stuff .. '\n'))
  end)

  self.read_stdout = async(function(self)
    if self.stdout == "" then
      await(job.stdout_data_condvar:wait())
    end

    local stdout = self.stdout
    self.stdout = ""
    return stdout
  end)

  self.read_stderr = async(function(self)
    if self.stderr == "" then
      await(job.stderr_data_condvar:wait())
    end

    local stderr = self.stderr
    self.stderr = ""
    return stderr
  end)

  -- if force is true, will stop it with sigkill
  self.stop = async(function(self, force)
    job:check_dead()

    local signal = force and "sigkill" or "sigterm"
    job.process_handle:kill(signal)

    await(job.exit_rx())

    self.exit_code = job.code
    self.signal = job.signal

    return Output.from_handle(self)
  end)

  self.output = async(function(self)
    job:check_dead()

    if job.opts.interactive then
      error("Should not be run on an interactive job")
    end

    await(job:wait_eof())

    self.exit_code = job.code
    self.signal = job.signal

    return Output.from_handle(self)
  end)

  self.status = async(function(self)
    job:check_dead()

    if job.opts.interactive then
      error("Should not be run on an interactive job")
    end

    await(self:wait_eof())

    local status = {
      exit_code = job.code,
      signal = job.signal,
    }

    function status:success()
      return self.exit_code == 0
    end

    return status
  end)

  -- asynchronously write, writes are queued
  self.write = async(function(self, stuff)
    job:check_dead()

    await(a.uv.write(job.stdin, stuff .. '\n'))
  end)

  self.read_stdout = async(function(self)
    job:check_dead()

    if self.stdout == "" then
      await(job.stdout_data_condvar:wait())
    end

    local stdout = self.stdout
    self.stdout = ""
    return stdout
  end)

  self.read_stderr = async(function(self)
    job:check_dead()

    if self.stderr == "" then
      await(job.stderr_data_condvar:wait())
    end

    local stderr = self.stderr
    self.stderr = ""
    return stderr
  end)

  return self
end

function Job:start()
  local job = self

  local handle = new_handle(job)

  job.process_handle, job.pid = uv.spawn(
    job.uv_opts.command,
    job.uv_opts,
    function(code, signal)
      local fn = async(function()
        job.code = code
        job.signal = signal
        await(job:close_everything())
        job.exit_tx(true)
      end)

      a.run(fn())
    end
  )

  job.stdout:read_start(function(err, data)
    assert(not err, err) -- fix this

    if not data then
      job.stdout_eof_tx(true)
    else
      handle.stdout = handle.stdout .. data
      job.stdout_data_condvar:notify_all()
    end
  end)

  job.stderr:read_start(function(err, data)
    assert(not err, err) -- fix this

    if not data then
      job.stderr_eof_tx(true)
    else
      handle.stderr = handle.stderr .. data
      job.stderr_data_condvar:notify_all()
    end
  end)

  if self.opts.writer then
    self.opts.writer:start()
  end

  return handle
end

local function run(opts)
  return Job.new(opts):start()
end

return {
  Job = function(opts) return Job.new(opts) end,
  run = run,
}
