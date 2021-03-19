local f = require'plenary.functional'

-- describe('arg', function()
--   it('should double arg', function()
--     local res = {f.double_arg(5)}
--     eq(res, {5, 5})
--   end)
-- end)

    local res = {f.double_arg(5)}
    dump(res)
    local res = {f.repeat_arg(10, true)}
    dump(res)
