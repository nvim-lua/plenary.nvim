local a = require("plenary.async_lib")
local async, await, await_all = a.async, a.await, a.await_all
local Condvar = a.util.Condvar
local channel = a.util.channel
local uv = vim.loop


local valid_handle_name
do
  local handle_names = {
    stdout = true,
    stderr = true,
    stdin = true,
  }

  valid_handle_name = function(name)
    if not handle_names[name] then
      error("not valid handle name")
    end
  end
end

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
---Thin wrapper around Job:spawn
Job.output = async(function(self)
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

function Handle.new(stdin_handle, stdout_handle, stderr_handle, spawn_opts)
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

    spawn_opts = spawn_opts,
  }, Handle)

  return self
end

function Handle:check_dead()
  assert(not self.dead, "The handle is not running anymore")
end

Handle.write = async(function(self, stuff)
  await(a.uv.write(self.stdin_handle, stuff .. '\n'))
end)

-- Handle.get_pipe = async(function(self, name)
--   valid_handle_name(name)

--   return name .. '_handle'
-- end)

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

Handle.raw_read = async(function(self, handle_name)
  assert(self.spawn_opts.raw_read == true, "Raw read must be enabled")
  valid_handle_name(handle_name)
  handle_name = handle_name .. '_handle'

  local tx, rx = channel.oneshot()

  local handle = self[handle_name]

  handle:read_start(function(err, data)
    handle:read_stop()

    assert(not err, err)

    tx(data or false)
  end)

  local res = await(rx())

  if res == false then
    return nil
  else
    return res
  end
end)

-- safety: when the process is killed, all read_start callbacks will be called with data == nil which means that eof has been hit
-- each callback will check for this and close the proper pipe
-- this means that pipes will always be closed properly and there will be no closing pipes while there is still output
-- which can lead to a broken pipe error in the process
-- if the process is not killed and stops naturally, eof will be hit naturally and the same process above happens
-- this means that if there are multiple queued reads it will not close before everything is finished
---if force is true, will stop it with sigkill
Handle.stop = async(function(self, force)
  self:check_dead()

  local signal = force and "sigkill" or "sigterm"
  self.process_handle:kill(signal)

  self.exit_code, self.signal = await(self.exit_rx())

  return Output.from_handle(self)
end)

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

-- TODO: allow pipes to be confirgurable
Job.spawn = function(self, spawn_opts)
  spawn_opts = spawn_opts or {}

  local uv_opts = create_uv_options(self.opts)

  local stdin, stdout, stderr = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
  uv_opts.stdio = { stdin, stdout, stderr }

  local job_handle = Handle.new(stdin, stdout, stderr, spawn_opts)

  job_handle.process_handle, job_handle.pid = uv.spawn(uv_opts.command, uv_opts, function(code, signal)
    local fn = async(function()
      await_all {
        a.uv.close(job_handle.process_handle),
        a.uv.close(stdin),
      }

      self.dead = true

      job_handle.exit_tx(code, signal)
    end)

    a.run(fn())
  end)

  if spawn_opts.raw_read == true then
    return job_handle
  end

  uv.read_start(stdout, function(err, data)
    local fn = async(function()
      assert(not err, err)

      if data == nil then
        print('stdout hit eof')
        job_handle.stdout_eof_tx(true)
        await(a.uv.close(stdout))
      else
        -- first update the data
        job_handle.stdout_data = job_handle.stdout_data .. data

        -- then notify everyone that is waiting on our data that it is ready
        job_handle.stdout_data_condvar:notify_all()
      end
    end)

    a.run(fn())
  end)

  -- this is the same as for stdout but for stderr
  uv.read_start(stderr, function(err, data)
    local fn = async(function()
      assert(not err, err)

      if data == nil then
        print('stderr hit eof')
        job_handle.stderr_eof_tx(true)
        await(a.uv.close(stderr))
      else
        job_handle.stderr_data = job_handle.stderr_data .. data

        job_handle.stderr_data_condvar:notify_all()
      end
    end)

    a.run(fn())
  end)

  return job_handle
end

return {
  Job = function(opts) return Job.new(opts) end,
}
