require('plenary.reload').reload_module('plenary')

-- TODO: We could add some stuff to delete this at the beginning to start fresh.
-- Probably would be useful to have an uninstall anyways

local neorocks = require('plenary.neorocks')
neorocks.install('luasocket', nil, true)

-- local job = neorocks._get_setup_job(false)
-- neorocks.ensure_installed('effil', 'effil')
-- neorocks.ensure_installed('lua-cjson')
-- neorocks.ensure_installed('luasocket')

-- if job then
--   job:start()
-- else
--   print("Already installed")
-- end

