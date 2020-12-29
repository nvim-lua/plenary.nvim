local shebang_prefixes = { '/usr/bin/', '/bin/', '/usr/bin/env ', '/bin/env ' }
local shebang_fts = {
  ['sh'] = 'sh',
  ['bash'] = 'bash',
  ['zsh'] = 'zsh',
  ['python'] = 'python',
  ['python2'] = 'python',
  ['python3'] = 'python',
  ['perl'] = 'perl',
}

local shebang = {}
for _, prefix in ipairs(shebang_prefixes) do
  for k, v in pairs(shebang_fts) do
    shebang[prefix .. k] = v
  end
end

return {
  extension = {
    ['fnl'] = 'fennel',
    ['janet'] = 'janet',
    ['jsx'] = 'javascriptreact',
    ['tsx'] = 'typescriptreact',
  },
  file_name = {
    ['showing_twitch_chat.kappa'] = 'PogChamp',
  },
  shebang = shebang
}
