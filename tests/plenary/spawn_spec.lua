local uv = vim.loop

local function test()
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  -- print("stdin", stdin)
  -- print("stdout", stdout)
  -- print("stderr", stderr)

  local handle, pid = uv.spawn("cat", {
    stdio = {stdin, stdout, stderr}
  }, function(code, signal) -- on exit
    print("exit code", code)
    print("exit signal", signal)
  end)

  -- print("process opened", handle, pid)

  uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then
      -- print("stdout chunk", stdout, data)
    else
      -- print("stdout end", stdout)
    end
  end)

  uv.read_start(stderr, function(err, data)
    assert(not err, err)
    if data then
      -- print("stderr chunk", stderr, data)
    else
      -- print("stderr end", stderr)
    end
  end)

  uv.write(stdin, "Hello World")

  uv.shutdown(stdin, function()
    -- print("stdin shutdown", stdin)
    uv.close(handle, function()
      uv.process_kill(handle, 15)
      -- print("process closed", handle, pid)
    end)
  end)
end

local function simple()
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local handle, pid = uv.spawn("cat", {
    stdio = {stdin, stdout, stderr}
  }, function(code, signal) -- on exit
    print("exit code", code)
    print("exit signal", signal)
  end)

  handle:close()
end
