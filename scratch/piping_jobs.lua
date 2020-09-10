-- TODO: Should make a no_listening param or similar.

require('plenary.reload').reload_module('plenary')

local Job = require('plenary.job')

local fzf = Job:new {
  command = 'fzf';

  writer = Job:new {
    command = "git",
    args = {"ls-files"},

    enable_handlers = false,
  },

  -- Still doesn't work if you don't pass these args and just run `fzf`
  args = {'--no-sort', '--filter', ''};
}

--[[

fzf_job = ...
git_job = ...

result = git_job | fzf_job
result = git_job >> fzf_job

ashkan suggests potentially using `/` __div as the way to pipe them.
result = git_job / fzf_job
--]]

print(vim.inspect(fzf:sync()))
