local path = require 'pl.path'

local ret = {}

local getTrace = function(filename, info)
  local index = info.traceback:find('\n%s*%[C]')
  info.traceback = info.traceback:sub(1, index)
  return info
end

ret.match = function(busted, filename)
  return path.extension(filename) == '.lua'
end

ret.load = function(busted, filename)
  local file, err = loadfile(filename)
  if not file then
    busted.publish({ 'error', 'file' }, { descriptor = 'file', name = filename }, nil, err, {})
  end
  return file, getTrace
end

return ret
