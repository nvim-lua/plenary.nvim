
require('plenary.reload').reload_module('plenary')

local Job = require('plenary.job')

local fzf = Job:new {
  command = 'fzf';

  writer = Job:new {
    command = "git",
    args = {"ls-files"},
  },

  -- Still doesn't work if you don't pass these args and just run `fzf`
  args = {'--no-sort', '--filter', 'job'};
}

print(vim.inspect(fzf:sync()))
