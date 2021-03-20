local a = require("plenary.async_lib")
local async, await, await_all = a.async, a.await, a.await_all
local Condvar = a.utils.Condvar
local channel = a.utils.channel
local uv = vim.loop

local maybe_close = async(function(uv_handle)
  if uv.is_closing(uv_handle) then
    await(a.uv.close(uv_handle))
  end
end)

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

  self.opts = opts

  return self
end

-- TODO: add support for piping jobs to each other
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

    -- TODO: writer should be in place of nil
    uv_opts.stdio = { nil, uv.new_pipe(false), uv.new_pipe(false) }

    uv_opts.cwd = opts.cwd
    uv_opts.env = opts.env

    return uv_opts
  end

  Job.output = async(function(self)
    assert(not self.opts.interactive == true, "Cannot get the output of an interactive job")

    local uv_opts = create_uv_options(self.opts)

    local stdout = uv_opts.stdio[2]
    local stderr = uv_opts.stdio[3]

    local exit_tx, exit_rx = channel.oneshot()
    local stdout_eof_tx, stdout_eof_rx = channel.oneshot()
    local stderr_eof_tx, stderr_eof_rx = channel.oneshot()

    local stdout_data = ""
    local stderr_data = ""

    local handle
    handle, _ = uv.spawn(uv_opts.command, uv_opts, function(code, signal)
      local fn = async(function()
        exit_tx(code, signal)
      end)

      a.run(fn())
    end)

    uv.read_start(stdout, function(err, data)
      assert(not err, err)

      if data == nil then
        stdout_eof_tx(true)
      else
        print('adding stdout', data)
        stdout_data = stdout_data .. data
      end
    end)

    uv.read_start(stderr, function(err, data)
      assert(not err, err)

      if data == nil then
        stderr_eof_tx(true)
      else
        stderr_data = stderr_data .. data
      end
    end)

    -- await the data before closing the pipes
    -- or there will be a broken pipe signal
    local res = await_all {
      stdout_eof_rx(),
      stderr_eof_rx(),
      exit_rx(),
    }

    local close = a.uv.close

    await_all {
      close(stdout),
      close(stderr),
      close(handle),
    }

    local code = res[3][1]
    local signal = res[3][2]

    return {
      stdout_data = stdout_data,
      stderr_data = stderr_data,
      code = code,
      signal = signal,
    }
  end)
end

local Handle = {}
Handle.__index = Handle

function Handle.new(stdout_handle, stderr_handle, stdin_handle)
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

Handle.read_stderr = async(function(self)
  if self.stderr_data == "" then
    await(self.stderr_data_condvar:wait())
  end

  local stderr_data = self.stderr_data
  self.stderr_data = ""
  return stderr_data
end)

-- if force is true, will stop it with sigkill
Handle.stop = async(function(self, force)
  self:check_dead()

  local signal = force and "sigkill" or "sigterm"
  self.process_handle:kill(signal)

  await(self.exit_rx())

  self.exit_code = self.code
  self.signal = self.signal

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

    uv_opts.stdio = { opts.stdin, opts.stdout, opts.stderr }

    uv_opts.cwd = opts.cwd
    uv_opts.env = opts.env

    return uv_opts
  end

  Job.spawn = async(function(self)
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
          job_handle.stdout_data_condvar:notify_all()

          job_handle.stdout_data = job_handle.stdout_data .. data
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
          job_handle.stderr_data_condvar:notify_all()

          job_handle.stderr_data = job_handle.stderr_data .. data
        end
      end)

      a.run(fn())
    end)
  end)
end

return {
  Job = function(opts) return Job.new(opts) end,
}
