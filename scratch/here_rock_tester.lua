
require('plenary.reload').reload_module('plenary')

-- local rocks = require('nvim_rocks')
-- rocks.ensure_installed('lua-cjson')
-- require('cjson')

local neorocks = require('plenary.neorocks')

neorocks.install('lua-cjson')
-- neorocks.remove('busted')
