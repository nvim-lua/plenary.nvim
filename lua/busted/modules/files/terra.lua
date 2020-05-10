local path = require 'pl.path'

local ret = {}
local terra_available, terralib = not not terralib, terralib --luacheck: ignore
if not terra_available then
  terra_available, terralib = pcall(require, 'terra') --otherwise, attempt to load terra as a shared library
end

local getTrace = function(filename, info)
  local index = info.traceback:find('\n%s*%[C]')
  info.traceback = info.traceback:sub(1, index)
  return info
end

ret.match = function(busted, filename)
  return path.extension(filename) == '.t'
end

ret.load = function(busted, filename)
  if not terra_available then
    error "unable to load terra, try running without terra language support enabled or installing terra."
  else
    local file, err = terralib.loadfile(filename)
    if not file then
      busted.publish({ 'error', 'file' }, { descriptor = 'file', name = filename }, nil, err, {})
    end
    return file, getTrace
  end
end

return ret
