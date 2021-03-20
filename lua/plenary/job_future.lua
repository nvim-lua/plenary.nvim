local a = require("plenary.async_lib")
local async, await, await_all = a.async, a.await, a.await_all
local Condvar = a.utils.Condvar
local channel = a.utils.channel
local uv = vim.loop

local maybe_close = async(function(uv_handle)
  if not uv.is_closing(uv_handle) then
    await(a.uv.close(uv_handle))
  end
end)

local Output = {}
Output.__index = Output

function Output.from_handle(handle)
  return setmetatable({
    stdout_data = handle.stdout_data,
    stderr_data = handle.stderr_data,
    exit_code = handle.exit_code,
    signal = handle.signal,
  }, Output)
end

function Output:stdout_lines()
  return vim.split(self.stdout_data, '\n', true)
end

function Output:stderr_lines()
  return vim.split(self.stderr_data, '\n', true)
end

function Output:success()
  return self.exit_code == 0
end

function Output:closed_normally()
  return self.signal == 0
end

local Job = {}
Job.__index = Job
Job.__concat = function(lhs, rhs)
  local new_job = Job.new(rhs.opts)
  new_job.opts.writer = lhs
  return new_job
end

function Job.new(opts)
  local self = setmetatable({opts = opts}, Job)

  return self
end

-- TODO: add support for piping jobs to each other
Job.output = async(function(self)
  print('running output')
  assert(not self.opts.interactive == true, "Cannot get the output of an interactive job")

  local handle = self:spawn()

  local stdout_data = await(handle:read_all_stdout())
  local stderr_data = await(handle:read_all_stderr())

  local exit_code, signal = await(handle:wait_done())

  return setmetatable({
    stdout_data = stdout_data,
    stderr_data = stderr_data,
    exit_code = exit_code,
    signal = signal,
  }, Output)
end)

local Handle = {}
Handle.__index = Handle

function Handle.new(stdin_handle, stdout_handle, stderr_handle)
  local exit_tx, exit_rx = channel.oneshot()
  local stdout_eof_tx, stdout_eof_rx = channel.oneshot()
  local stderr_eof_tx, stderr_eof_rx = channel.oneshot()

  local self = setmetatable({
    -- data that was received
    stdout_data = "",
    stderr_data = "",

    -- actual job handles
    stdout_handle = stdout_handle,
    stderr_handle = stderr_handle,
    stdin_handle = stdin_handle,

    -- control flow
    exit_tx = exit_tx,
    exit_rx = exit_rx,
    stdout_eof_tx = stdout_eof_tx,
    stdout_eof_rx  = stdout_eof_rx,
    stderr_eof_tx = stderr_eof_tx,
    stderr_eof_rx = stderr_eof_rx,

    -- data condvars
    stdout_data_condvar = Condvar.new(),
    stderr_data_condvar = Condvar.new(),

    -- lock
    dead = false,
  }, Handle)

  return self
end

function Handle:check_dead()
  assert(not self.dead, "Cannot use this option when the self is dead")
end

Handle.write = async(function(self, stuff)
  await(a.uv.write(self.stdin_handle, stuff .. '\n'))
end)

Handle.read_stdout = async(function(self)
  if self.stdout_data == "" then
    await(self.stdout_data_condvar:wait())
  end

  local stdout_data = self.stdout_data
  self.stdout_data = ""
  return stdout_data
end)

Handle.read_all_stdout = async(function(self)
  await(self.stdout_eof_rx())

  local stdout_data = self.stdout_data
  self.stdout_data = ""
  return stdout_data
end)

Handle.read_all_stderr = async(function(self)
  await(self.stderr_eof_rx())

  local stderr_data = self.stderr_data
  self.stderr_data = ""
  return stderr_data
end)

Handle.read_stderr = async(function(self)
  if self.stderr_data == "" then
    await(self.stderr_data_condvar:wait())
  end

  local stderr_data = self.stderr_data
  self.stderr_data = ""
  return stderr_data
end)

Handle.wait_done = async(function(self)
  self:check_dead()

  return await(self.exit_rx())
end)

-- if force is true, will stop it with sigkill
Handle.stop = async(function(self, force)
  self:check_dead()

  local signal = force and "sigkill" or "sigterm"
  self.process_handle:kill(signal)

  await(self.exit_rx())

  return Output.from_handle(self)
end)

do
  local function create_uv_options(opts)
    local uv_opts = {}
    uv_opts.args = {}

    for i, arg in ipairs(opts) do
      if i == 1 then
        uv_opts.command = arg
      else
        uv_opts.args[i - 1] = arg
      end
    end

    uv_opts.cwd = opts.cwd
    uv_opts.env = opts.env

    return uv_opts
  end

  Job.spawn = function(self, spawn_opts)
    local uv_opts = create_uv_options(self.opts)

    local stdin, stdout, stderr = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
    uv_opts.stdio = { stdin, stdout, stderr }

    local job_handle = Handle.new(stdin, stdout, stderr)

    job_handle.process_handle, job_handle.pid = uv.spawn(uv_opts.command, uv_opts, function(code, signal)
      local fn = async(function()
        await_all {
          a.uv.close(job_handle.process_handle),
          maybe_close(job_handle.stdout_handle),
          maybe_close(job_handle.stderr_handle),
          maybe_close(job_handle.stdin_handle),
        }

        self.dead = true
        self.exit_code = code
        self.signal = signal
        job_handle.exit_tx(code, signal)
      end)

      a.run(fn())
    end)

    uv.read_start(stdout, function(err, data)
      local fn = async(function()
        assert(not err, err)

        if data == nil then
          job_handle.stdout_eof_tx(true)
          await(maybe_close(stdout))
        else
          job_handle.stdout_data = job_handle.stdout_data .. data

          job_handle.stdout_data_condvar:notify_all()
        end
      end)

      a.run(fn())
    end)

    uv.read_start(stderr, function(err, data)
      local fn = async(function()
        assert(not err, err)

        if data == nil then
          job_handle.stderr_eof_tx(true)
          await(maybe_close(stderr))
        else
          job_handle.stderr_data = job_handle.stderr_data .. data

          job_handle.stderr_data_condvar:notify_all()
        end
      end)

      a.run(fn())
    end)

    return job_handle
  end
end

return {
  Job = function(opts) return Job.new(opts) end,
}
