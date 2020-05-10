local app = require 'pl.app'
local io = io

return function(options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.base'()
  local language = require('busted.languages.' .. options.language)

  handler.suiteEnd = function()
    local system = app.platform()
    local sayer_pre, sayer_post
    local messages

    if system == 'Linux' then
      sayer_pre = 'espeak -s 160 '
      sayer_post = ' > /dev/null 2>&1'
    elseif system and system:match('^Windows') then
      sayer_pre = 'echo '
      sayer_post = ' | ptts'
    else
      sayer_pre = 'say '
      sayer_post = ''
    end

    if handler.failuresCount > 0 then
      messages = language.failure_messages
    else
      messages = language.success_messages
    end

    io.popen(sayer_pre .. '"' .. messages[math.random(1, #messages)] .. '"' .. sayer_post)

    return nil, true
  end

  busted.subscribe({ 'suite', 'end' }, handler.suiteEnd)

  return handler
end
