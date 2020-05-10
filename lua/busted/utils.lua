return {
  copy_interpreter_args = function(arguments)
    -- copy non-positive command-line args auto-inserted by Lua interpreter
    if arguments and _G.arg then
      local i = 0
      while _G.arg[i] do
        arguments[i] = _G.arg[i]
        i = i - 1
      end
    end
  end,

  split = require 'pl.utils'.split,

  shuffle = function(t, seed)
    if seed then math.randomseed(seed) end
    local n = #t
    while n >= 2 do
      local k = math.random(n)
      t[n], t[k] = t[k], t[n]
      n = n - 1
    end
    return t
  end,

  urandom = function()
    local f = io.open('/dev/urandom', 'rb')
    if not f then return nil end
    local s = f:read(4) f:close()
    local bytes = {s:byte(1, 4)}
    local value = 0
    for _, v in ipairs(bytes) do
      value = value * 256 + v
    end
    return value
  end,
}
