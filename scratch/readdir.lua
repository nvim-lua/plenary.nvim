local fs = require('plenary.fs')

local do_it = function()
  for _, entry in fs.read_dir { dir = "/home/brian/code", hidden = false } do
    dump(entry)
  end
end

a.run(do_it, function() print('done') end)
