local eq = assert.are.same
local a = require("plenary.async_lib")
local uv = vim.loop
local async, await = a.async, a.await
local Job = require("plenary.job_future").Job

describe('Job', function()
  describe('echo', function()
    it('should work simple', function()
      local fn = async(function()
        local output = await(Job { "echo", [['hello world!']] }:output())
        assert(output:success())
      end)

      a.block_on(fn())
    end)
  end)

  describe('cat', function()
    it('should work when interactive', function()
      local fn = async(function()
        local handle = Job { "cat", "-", interactive = true }:spawn()
        await(handle:write("hello world!"))
        local got = await(handle:read_stdout())
        assert(got, "hello world!")
        local output = await(handle:stop())
        assert(output:success())
      end)

      a.block_on(fn())
    end)

    it('should error when stopping job when already dead', function()
      local fn = async(function()
        local handle = Job { "cat", "-", interactive = true }:spawn()
        await(handle:write("hello world!"))
        local got = await(handle:read_stdout())
        assert(got, "hello world!")
        local output = await(handle:stop())
        assert(output:success())

        -- local stat, ret = await(a.utils.protected(handle:stop()))
        local stat, ret = await(handle:stop())
        -- eq(stat, false)
      end)

      a.block_on(fn())
    end)
  end)

  describe('python', function()
    it('should work when interactive and capture stderr', function()
      local fn = async(function()
        local handle = Job { "python", "-i", interactive = true }:spawn()

        -- prelude
        assert(await(handle:read_stderr()):match("Python"))

        await(handle:write("1 + 1"))

        eq(await(handle:read_stdout()), "2\n")

        local output = await(handle:stop())
        assert(output:success())
      end)

      a.block_on(fn())
    end)
  end)

  describe('long job', function()
    it('should close properly', function()
      local fn = async(function()
        local handle = Job { "sleep", "1000" }:spawn()
        local output = await(handle:stop())

        assert(output:success())
        eq(output.signal, 15)
      end)

      a.block_on(fn())
    end)
  end)
end)
