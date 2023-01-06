local Job = require "plenary.job"

local Timing = {}

function Timing:log(name)
  self[name] = vim.loop.uptime()
end

function Timing:check(from, to, min_elapsed)
  assert(self[from], "did not log " .. from)
  assert(self[to], "did not log " .. to)
  local elapsed = self[to] - self[from]
  assert(
    min_elapsed <= elapsed,
    string.format("only took %s to get from %s to %s - expected at least %s", elapsed, from, to, min_elapsed)
  )
end

describe("Async test", function()
  it("can resume testing with vim.defer_fn", function()
    local co = coroutine.running()
    assert(co, "not running inside a coroutine")

    local timing = setmetatable({}, { __index = Timing })

    vim.defer_fn(function()
      coroutine.resume(co)
    end, 200)
    timing:log "before"
    coroutine.yield()
    timing:log "after"
    timing:check("before", "after", 0.1)
  end)

  it("can resume testing from job callback", function()
    local co = coroutine.running()
    assert(co, "not running inside a coroutine")

    local timing = setmetatable({}, { __index = Timing })

    Job:new({
      command = "bash",
      args = {
        "-ce",
        [[
        sleep 0.2
        echo hello
        sleep 0.2
        echo world
        sleep 0.2
        exit 42
      ]],
      },
      on_stdout = function(_, data)
        timing:log(data)
      end,
      on_exit = function(_, exit_status)
        timing:log "exit"
        --This is required so that the rest of the test will run in a proper context
        vim.schedule(function()
          coroutine.resume(co, exit_status)
        end)
      end,
    }):start()
    timing:log "job started"
    local exit_status = coroutine.yield()
    timing:log "job finished"
    assert.are.equal(exit_status, 42)

    timing:check("job started", "job finished", 0.3)
    timing:check("job started", "hello", 0.1)
    timing:check("hello", "world", 0.1)
    timing:check("world", "job finished", 0.1)
  end)
end)
