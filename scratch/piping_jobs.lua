-- TODO: Should make a no_listening param or similar.

require('plenary.reload').reload_module('plenary')

local Job = require('plenary.job')

-- fdfind | fzf --no-sort

local fzf = Job:new {
  writer = Job:new {
    command = 'fdfind',
  },

  command = 'fzf';

  -- Still doesn't work if you don't pass these args and just run `fzf`
  args = {'--no-sort', '--filter', 'action'};
}

print(vim.inspect(fzf:sync()))

--[[

fzf_job = ...
git_job = ...

result = git_job | fzf_job
result = git_job >> fzf_job

ashkan suggests potentially using `/` __div as the way to pipe them.
result = git_job / fzf_job
--]]

