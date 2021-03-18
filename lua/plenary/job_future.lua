local a = require("plenary.async_lib")
local async, await, await_all = a.async, a.await, a.await_all
local Condvar = a.utils.Condvar
local channel = a.utils.channel
local uv = vim.loop

local Output = {}
Output.__index = Output

function Output._from_handle(handle)
  return setmetatable(handle, Output)
end

function Output:stdout_lines()
  return vim.split(self.stdout, '\n', true)
end

function Output:stderr_lines()
  return vim.split(self.stderr, '\n', true)
end

function Output:stdout()
  return self.stdout
end

function Output:stderr()
  return self.stderr
end

local create_uv_options
do
  local pipe_indices = { stdin = 1, stdout = 2, stderr = 3 }

  create_uv_options = function(opts)
    local uv_opts = {}
    uv_opts.args = {}

    for i, arg in ipairs(opts) do
      if i == 1 then
        uv_opts.command = arg
      else
        uv_opts.args[i - 1] = arg
      end
    end

    uv_opts.stdio = { uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false) }

    uv_opts.cwd = opts.cwd
    uv_opts.env = opts.env

    return setmetatable(uv_opts, {__index = function(t, k)
      return rawget(t.stdio, rawget(pipe_indices, k))
    end})
  end
end

local function run(opts)
  local uv_opts = create_uv_options(opts)

  dump(uv_opts)

  local exit_tx, exit_rx = channel.oneshot()
  local stdout_tx, stdout_rx = channel.oneshot()
  local stderr_tx, stderr_rx = channel.oneshot()

  local uv_handle, pid = uv.spawn(
    uv_opts.command,
    uv_opts,
    function()
      exit_tx(true)
    end
  )

  local stdout_data_condvar = Condvar.new()
  local stderr_data_condvar = Condvar.new()

  local Handle = {
    stdout = "",
    stderr = "",
  }

  Handle.stop = async(function(self)
    local close = a.uv.close

    await_all {
      close(uv_opts.stdout),
      close(uv_opts.stderr),
      close(uv_opts.stdin),
      close(uv_handle)
    }
  end)

  uv_opts.stdout:read_start(function(err, data)
    assert(not err, err) -- fix this

    if not data then
      stdout_tx(true)
    else
      print('adding to stdout', data)
      Handle.stdout = Handle.stdout .. data
      stdout_data_condvar:notify_all()
    end
  end)

  uv_opts.stderr:read_start(function(err, data)
    assert(not err, err) -- fix this

    if not data then
      stderr_tx(true)
    else
      Handle.stderr = Handle.stderr .. data
      stderr_data_condvar:notify_all()
    end
  end)

  Handle.output = async(function(self)
    await_all {
      exit_rx(),
      stdout_rx(),
      stderr_rx(),
    }

    print('got here')

    await(self:stop())

    print('stopped self')

    return Output._from_handle(self)
  end)

  Handle.write = async(function(self, stuff)
    await(a.uv.write(uv_opts.stdin, stuff .. '\n'))
  end)

  Handle.read_stdout = async(function(self)
    if self.stdout == "" then
      await(stdout_data_condvar:wait())
    end

    local stdout = self.stdout
    self.stdout = ""
    return stdout
  end)

  Handle.read_stderr = async(function(self)
    if self.stderr == "" then
      await(stderr_data_condvar:wait())
    end

    local stderr = self.stderr
    self.stderr = ""
    return stderr
  end)

  return Handle
end

return {
  run = run,
}
