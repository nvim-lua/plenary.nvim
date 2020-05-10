local path = require 'pl.path'
local hasMoon, moonscript = pcall(require, 'moonscript')
local utils = require 'busted.utils'

return function()
  local loadOutputHandler = function(busted, output, options)
    local handler

    utils.copy_interpreter_args(options.arguments)
    local success, err = pcall(function()
      if output:match('%.lua$') then
        handler = dofile(path.normpath(output))
      elseif hasMoon and output:match('%.moon$') then
        handler = moonscript.dofile(path.normpath(output))
      else
        handler = require('busted.outputHandlers.' .. output)
      end
    end)

    if not success and err:match("module '.-' not found:") then
      success, err = pcall(function() handler = require(output) end)
    end

    if not success then
      busted.publish({ 'error', 'output' }, { descriptor = 'output', name = output }, nil, err, {})
      handler = require('busted.outputHandlers.' .. options.defaultOutput)
    end

    if options.enableSound then
      require 'busted.outputHandlers.sound'(options)
    end

    handler(options):subscribe(options)
  end

  return loadOutputHandler
end
