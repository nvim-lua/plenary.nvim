RELOAD('plenary')
local native = require'plenary.curl.native'

P(native.get('https://example.com', { headers = 'AUTH: token 1234' }))
