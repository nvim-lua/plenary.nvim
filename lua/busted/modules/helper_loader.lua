local path = require 'pl.path'
local hasMoon, moonscript = pcall(require, 'moonscript')
local utils = require 'busted.utils'

return function()
  local loadHelper = function(busted, helper, options)
    local old_arg = _G.arg
    local success, err = pcall(function()
      utils.copy_interpreter_args(options.arguments)
      _G.arg = options.arguments
      if helper:match('%.lua$') then
        dofile(path.normpath(helper))
      elseif hasMoon and helper:match('%.moon$') then
        moonscript.dofile(path.normpath(helper))
      else
        require(helper)
      end
    end)

    arg = old_arg   --luacheck: ignore

    if not success then
      busted.publish({ 'error', 'helper' }, { descriptor = 'helper', name = helper }, nil, err, {})
    end
  end

  return loadHelper
end
