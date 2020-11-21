local Job = require 'plenary.job'

local git = {}

-- TODO(conni2461): What else? Need more ideas :)

local make_commit = function(commit_line)
  local rev, author, date, msg = string.match(commit_line, '([^:]+):([^:]+):([^:]+):(.*)')
  return {
    revision = rev,
    author = author,
    date = date,
    message = mes,
  }
end

git.on_logs = function(opts, each_callback, exit_callback)
  opts = opts or {}

  opts.cwd = opts.cwd or vim.loop.cwd()
  opts.file = opts.file or nil

  -- TODO(conni2461): git search

  local output = {}
  local j = Job:new {
    command = 'git',
    args = { '--no-pager', 'log', '--format=%h:%an:%aD:%s', file },
    cwd = cwd,
    on_stdout = function(_, line)
      local commit = git.make_commit(line)
      table.insert(output, commit)
      if each_callback then
        each_callback(commit)
      end
    end,
    on_exit = function()
      if exit_callback then
        exit_callback(output)
      end
    end
  }

  if not each_callback and not exit_callback then
    j:sync()
    return output
  else
    j:start()
  end
end

git.on_tags = function(opts, each_callback, exit_callback)
  opts = opts or {}

  opts.cwd = opts.cwd or vim.loop.cwd()

  local output = {}
  local j = Job:new {
    command = 'git',
    args = { 'tag' },
    cwd = cwd,
    on_stdout = function(_, line)
      table.insert(output, line)
      each_callback(output)
    end,
    on_exit = function()
      exit_callback(output)
    end
  }

  if not each_callback and not exit_callback then
    j:sync()
    return output
  else
    j:start()
  end
end

git.on_branches = function(cwd, each_callback, exit_callback)
  opts = opts or {}

  opts.cwd = opts.cwd or vim.loop.cwd()

  local output = {}
  local j = Job:new {
    command = 'git',
    args = { 'branch', '--all' },
    cwd = cwd,
    on_stdout = function(_, line)
      if not string.find(line, 'HEAD') then
        line = string.gsub(line, '.* ', '')
        line = string.gsub(line, '^remotes/.*/', '')
        table.insert(output, line)
      end
      each_callback(output)
    end,
    on_exit = function()
      local hash = {}
      for _, v in ipairs(output) do
          hash[v] = true
      end
      local res = {}
      for k, _ in pairs(hash) do
          res[#res+1] = k
      end
      exit_callback(output)
    end
  }

  if not each_callback and not exit_callback then
    j:sync()
    return output
  else
    j:start()
  end
end

-- TODO(conni2461): Need to be reworked to work like git.on_commits
git.status = function(cwd, callback)
  local output = {}
  Job:new({
    command = 'git',
    args = { 'status', '-s' },
    cwd = cwd,
    on_stdout = function(_, line)
      table.insert(output, line)
    end,
    on_exit = function()
      callback(output)
    end
  }):start()
end

git.status_modified = function(cwd, callback)
  local output = {}
  Job:new({
    command = 'git',
    args = { 'status', '-s' },
    cwd = cwd,
    on_stdout = function(_, line)
      local mod, _ = string.match(line, '(..)%s(.+)')
      if mod ~= 'A ' and mod ~= 'M ' and mod ~= 'R ' and mod ~= 'D ' then
        table.insert(output, line)
      end
    end,
    on_exit = function()
      callback(output)
    end
  }):start()
end

git.status_added = function(cwd, callback)
  local output = {}
  Job:new({
    command = 'git',
    args = { 'status', '-s' },
    cwd = cwd,
    on_stdout = function(_, line)
      local mod, _ = string.match(line, '([AMR]).%s(.+)')
      if mod then
        table.insert(output, line)
      end
    end,
    on_exit = function()
      callback(output)
    end
  }):start()
end

return git
