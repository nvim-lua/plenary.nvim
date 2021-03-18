local a = require("plenary.async_lib")
local async, await, await_all = a.async, a.await, a.await_all
local Condvar = a.utils.Condvar
local channel = a.utils.channel
local uv = vim.loop

local Job = {}
Job.__index = Job

local function create_uv_options(opts)
  local uv_opts = {}
  uv_opts.args = {}

  for i, arg in ipairs(opts) do
    if i == 1 then
      uv_opts.command = arg
    else
      uv_opts.args[i] = arg
    end
  end

  uv_opts.stdio = { uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false) }

  uv_opts.cwd = opts.cwd
  uv_opts.env = opts.env

  return options
end

---local res = run { "ls", "-A", cwd = "./" }:output():stdout_lines()
---local handle = run { "python", "-i" }
---handle:send("print(5 + 5)")
---local res = await(handle:read_line())
---await(handle:stop())
---local output = await(run { "cat", "path/to/smiley.cat" }:output()):stdout()
local function run(opts)
  local uv_opts = create_uv_options(opts)

  local finish_tx, finish_rx = channel.oneshot.new()
  local stdout_tx, stdout_rx = channel.oneshot.new()
  local stderr_tx, stderr_rx = channel.oneshot.new()

  local uv_handle, pid = uv.spawn(
    uv_opts.command,
    uv_opts,
    function()
      finish_tx(true)
    end
  )

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
      Handle.stdout = Handle.stdout .. data
    end
  end)

  uv_opts.stderr:read_start(function(err, data)
    assert(not err, err) -- fix this

    if not data then
      stderr_tx(true)
    else
      Handle.stderr = Handle.stderr .. data
    end
  end)

  Handle.output = async(function(self)
    await_all {
      finish_rx(),
      stdout_rx(),
      stderr_rx(),
    }

    await(self:stop())

    return Output._from_handle(self)
  end)

  Handle.write = async(function(self, stuff)
    await(a.uv.write(uv_opts.stdin, stuff .. '\n'))
  end)

  return Handle
end

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
