local a = require("plenary.async_lib")
local async, await, await_all = a.async, a.await, a.await_all
local Condvar = a.utils.Condvar
local channel = a.utils.channel
local uv = vim.loop

local function double_arg(...)
  return ..., ...
end

local function repeat_arg(..., times)
  if times == 0 then return ... end

  return repeat_arg(double_arg(...), times - 1)
end

local function clear_tbl(tbl)
  for k in pairs(t) do
    t[k] = nil
  end
end

local function tbl_with_size(n)
end

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

Job.__add = function(lhs, rhs)
end

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
  self.stdout_tx, self.stdout_rx = channel.oneshot()
  self.stderr_tx, self.stderr_rx = channel.oneshot()

  self.stdout_data_condvar = Condvar.new()
  self.stderr_data_condvar = Condvar.new()
end

function Job:create_pipes()
  self.stdout = self.stdout or uv.new_pipe(false)
  self.stderr = self.stderr or uv.new_pipe(false)
  self.stdin = self.stdin or uv.new_pipe(false)
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

    local close = a.uv.close

    await_all {
      close(job.stdout),
      close(job.stderr),
      close(job.stdin),
    }

    local signal = force and "sigkill" or "sigterm"

    job.uv_handle:kill(signal)

    print('after sigterm')

    await(job.exit_rx())

    print('after await channel')

    self.exit_code = job.code
    self.signal = job.signal

    return Output.from_handle(self)
  end)

  self.output = async(function(self)
    job:check_dead()

    if job.opts.interactive then
      error("Should not be run on an interactive job")
    end

    local close = a.uv.close

    await_all {
      job.stdout_rx(),
      job.stderr_rx(),
      job.exit_rx(),
    }

    -- must close after awaiting output
    -- or will have broken pipe
    await_all {
      close(job.stdout),
      close(job.stderr),
      close(job.stdin),
    }

    self.exit_code = job.code
    self.signal = job.signal

    return Output.from_handle(self)
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

  job.uv_handle, job.pid = uv.spawn(
    job.uv_opts.command,
    job.uv_opts,
    function(code, signal)
      job.code = code
      job.signal = signal
      uv.close(job.uv_handle)
      job.exit_tx(true)
    end
  )

  job.stdout:read_start(function(err, data)
    assert(not err, err) -- fix this

    if not data then
      job.stdout_tx(true)
    else
      handle.stdout = handle.stdout .. data
      job.stdout_data_condvar:notify_all()
    end
  end)

  job.stderr:read_start(function(err, data)
    assert(not err, err) -- fix this

    if not data then
      job.stderr_tx(true)
    else
      handle.stderr = handle.stderr .. data
      job.stderr_data_condvar:notify_all()
    end
  end)

  return handle
end

local function run(opts)
  return Job.new(opts):start()
end

return {
  Job = function(opts) return Job.new(opts) end,
  run = run,
}
