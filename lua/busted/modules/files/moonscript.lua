local path = require 'pl.path'

local ok, moonscript, line_tables, util = pcall(function()
  return require 'moonscript', require 'moonscript.line_tables', require 'moonscript.util'
end)

local _cache = {}

-- find the line number of `pos` chars into fname
local lookup_line = function(fname, pos)
  if not _cache[fname] then
    local f = io.open(fname)
    _cache[fname] = f:read('*a')
    f:close()
  end

  return util.pos_to_line(_cache[fname], pos)
end

local rewrite_linenumber = function(fname, lineno)
  local tbl = line_tables['@' .. fname]
  if fname and tbl then
    for i = lineno, 0 ,-1 do
      if tbl[i] then
        return lookup_line(fname, tbl[i])
      end
    end
  end

  return lineno
end

local rewrite_filename = function(filename)
  -- sometimes moonscript gives files like [string "./filename.moon"], so
  -- we'll chop it up to only get the filename.
  return filename:match('string "(.+)"') or filename
end

local rewrite_traceback = function(fname, trace)
  local rewrite_one = function(line, pattern, sub)
    if line == nil then return '' end

    local fname, lineno = line:match(pattern)

    if fname and lineno then
      fname = rewrite_filename(fname)
      local new_lineno = rewrite_linenumber(fname, tonumber(lineno))
      if new_lineno then
        line = line:gsub(sub:format(tonumber(lineno)), sub:format(tonumber(new_lineno)))
      end
    end

    return line
  end

  local lines = {}
  local j = 0

  for line in trace:gmatch('[^\r\n]+') do
    j = j + 1
    line = rewrite_one(line, '%s*(.-):(%d+): ', ':%d:')
    line = rewrite_one(line, '<(.*):(%d+)>', ':%d>')
    lines[j] = line
  end

  return '\n' .. table.concat(lines, trace:match('[\r\n]+')) .. '\n'
end

local ret = {}

local getTrace = function(filename, info)
  local index = info.traceback:find('\n%s*%[C]')
  info.traceback = info.traceback:sub(1, index)

  info.short_src = rewrite_filename(info.short_src)
  info.traceback = rewrite_traceback(filename, info.traceback)
  info.linedefined = rewrite_linenumber(filename, info.linedefined)
  info.currentline = rewrite_linenumber(filename, info.currentline)

  return info
end

local rewriteMessage = function(filename, message)
  local fname, line, msg = message:match('^([^\n]-):(%d+): (.*)')
  if not fname then
    return message
  end

  fname = rewrite_filename(fname)
  line = rewrite_linenumber(fname, tonumber(line))

  return fname .. ':' .. tostring(line) .. ': ' .. msg
end

ret.match = function(busted, filename)
  return ok and path.extension(filename) == '.moon'
end

ret.load = function(busted, filename)
  local file, err = moonscript.loadfile(filename)
  if not file then
    busted.publish({ 'error', 'file' }, { descriptor = 'file', name = filename }, nil, err, {})
  end
  return file, getTrace, rewriteMessage
end

return ret
