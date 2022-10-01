local shebang_prefixes = { '/usr/bin/', '/bin/', '/usr/bin/env ', '/bin/env ' }
local shebang_fts = {
  ['fish'] = 'fish',
  ['perl'] = 'perl',
  ['python'] = 'python',
  ['python2'] = 'python',
  ['python3'] = 'python',
  ['bash'] = 'sh',
  ['sh'] = 'sh',
  ['zsh'] = 'zsh',
}

local shebang = {}
for _, prefix in ipairs(shebang_prefixes) do
  for k, v in pairs(shebang_fts) do
    shebang[prefix .. k] = v
  end
end

return {
  extension = {
    ['_coffee'] = 'coffee',
    ['astro'] = 'astro',
    ['cljd'] = 'clojure',
    ['coffee'] = 'coffee',
    ['dart'] = 'dart',
    ['erb'] = 'eruby',
    ['ex'] = 'elixir',
    ['exs'] = 'elixir',
    ['fnl'] = 'fennel',
    ['gd'] = 'gdscript',
    ['gql'] = 'graphql',
    ['gradle'] = 'groovy',
    ['graphql'] = 'graphql',
    ['hbs'] = 'handlebars',
    ['hdbs'] = 'handlebars',
    ['janet'] = 'janet',
    ['jl'] = 'julia',
    ['jsx'] = 'javascriptreact',
    ['kt'] = 'kotlin',
    ['nix'] = 'nix',
    ['plist'] = 'xml',
    ['purs'] = 'purescript',
    ['res'] = 'rescript',
    ['resi'] = 'rescript',
    ['rkt'] = 'racket',
    ['svelte'] = 'svelte',
    ['tres'] = 'gdresource',
    ['tscn'] = 'gdresource',
    ['tsx'] = 'typescriptreact',
    ['sol'] = 'solidity',
  },
  file_name = {
    ['cakefile'] = 'coffee',
    ['.babelrc'] = 'json',
    ['.eslintrc'] = 'json',
    ['.firebaserc'] = 'json',
    ['.prettierrc'] = 'json',
  },
  shebang = shebang
}
