require('plenary.reload').reload_module('plenary')

-- TODO: We could add some stuff to delete this at the beginning to start fresh.
-- Probably would be useful to have an uninstall anyways

local neorocks = require('plenary.neorocks')

-- local job = neorocks._get_setup_job(false)
neorocks.install('effil', 'effil')
neorocks.install('lua-cjson')
neorocks.install('luasocket')

-- if job then
--   job:start()
-- else
--   print("Already installed")
-- end

