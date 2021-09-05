local B = {}
local stat = require "plenary.benchmark.stat"

local get_stat = function(runs, fun)
  local result = {}
  local start = vim.loop.hrtime()

  for i = 1, runs do
    fun()
    result[i] = vim.loop.hrtime() - start
  end

  local ret = {}

  ret.elapsed = vim.loop.hrtime() - start
  ret.max, ret.min = stat.maxmin(result)
  ret.mean = stat.mean(result)
  ret.median = stat.median(result)
  ret.std = stat.std_dev(result)

  return ret
end

---@class benchmark_run_opts
---@field warmup number @number of initial runs before starting to track time.
---@field runs number @number of runs to make
---@field fun function @function to execute

---Benchmark a function
---@param name string @benchmark name
---@param opts benchmark_run_opts
B.run = function(name, opts)
  for i = 1, opts.warmup do
    opts.fun()
  end

  local res = get_stat(opts.runs, opts.fun)

  print(('("%s") Benchmark: \n\n  - total elapsed time: %.3fms'):format(name, res.elapsed))
  print("  - runs: " .. opts.runs)
  print(
    ("  - min: %.3fs, max: %.3fs, mean: %.3fs, median: %fs, std: %fs\n"):format(
      res.min,
      res.max,
      res.mean,
      res.median,
      res.std
    )
  )

  return res
end

---@class benchmark_compare_opts
---@field warmup number @number of initial runs before starting to track time.
---@field runs number @number of runs to make
---@field new function @function to test
---@field base function @function to compare against

---Compare between {fun1} and {fun1} results
---@param name string @benchmark name
---@param opts benchmark_compare_opts
B.compare = function(name, opts)
  for i = 1, opts.warmuwarmup do
    opts.new()
    opts.base()
  end

  local base_result = get_stat(opts.runs, opts.base)
  local new_result = get_stat(opts.runs, opts.new)
  ---
end

return B
