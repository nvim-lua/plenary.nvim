local scan = require'plenary.scandir'
local Job = require'plenary.job'
local os_sep = require'plenary.path'.path.sep
local eq = assert.are.same

local contains = function(tbl, str)
  for _, v in ipairs(tbl) do
    if v == str then return true end
  end
  return false
end

local contains_match = function(tbl, str)
  for _, v in ipairs(tbl) do
    if v:match(str) then return true end
  end
  return false
end

local compare_tables = function(expected, given, cwd)
  local found = 0
  for _, v in ipairs(expected) do
    for k, w in ipairs(given) do
      if v == w:sub(#cwd + 2, -1) then
        found = found + 1
        goto continue
      end
    end
    ::continue::
  end
  return found
end

local fd_cmd = (function()
  if 1 == vim.fn.executable('fd') then
    return 'fd'
  else
    return 'fdfind'
  end
end)()

describe('scandir', function()
  describe('can list all files recursive', function()
    it('with cwd', function()
      local dirs = scan.scan_dir('.')
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { '.', '--type', 'f', '-I' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
    end)

    -- TODO(conni2461): Doesn't run in ci
    -- it('with homedir', function()
    --   local dirs = scan.scan_dir(vim.fn.expand('~'))
    --   local job_dirs = Job:new({
    --     command = fd_cmd,
    --     args = { '.', '-I', '--type', 'f', '--type', 'l' },
    --     cwd = vim.fn.expand('~')
    --   }):sync()
    --   eq('table', type(dirs))
    --   eq(table.getn(job_dirs), table.getn(dirs))
    --   eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, vim.fn.expand('~')))
    -- end)

    it('and callback gets called for each entry', function()
      local count = 0
      local dirs = scan.scan_dir('.', { on_insert = function() count = count + 1 end })
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { '.', '--type', 'f', '-I' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
      eq(count, #dirs)
      eq(count, #job_dirs)
    end)

    it('with multiple paths', function()
      -- TODO(conni2461): Diabled on windows because windows doesn't like these jobs :sob:
      if os_sep == '\\' then return end

      local dirs = scan.scan_dir({ './lua' , './tests'})
      local job_dirs1 = Job:new({
        command = fd_cmd,
        args = { '.', '--type', 'f', '-I' },
        cwd = 'lua'
      }):sync()

      local job_dirs2 = Job:new({
        command = fd_cmd,
        args = { '.', '--type', 'f', '-I' },
        cwd = 'tests'
      }):sync()
      local job_dirs = {}
      for _, v in ipairs(job_dirs1) do
        table.insert(job_dirs, 'lua/' .. v)
      end
      for _, v in ipairs(job_dirs2) do
        table.insert(job_dirs, 'tests/' .. v)
      end

      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    end)

    it('with hidden files', function()
      local dirs = scan.scan_dir('.', { hidden = true })
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { '.', '--type', 'f', '-I', '--hidden' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    end)

    -- TODO(conni2461): Doesn't run in ci
    -- it('with hidden files in homedir', function()
    --   local dirs = scan.scan_dir(vim.fn.expand('~'), { hidden = true })
    --   local job_dirs = Job:new({
    --     command = fd_cmd,
    --     args = { '.', '--type', 'f', '--type', 'l', '-I', '--hidden', '--type' },
    --     cwd = vim.fn.expand('~')
    --   }):sync()
    --   eq('table', type(dirs))
    --   local in_range = false
    --   if table.getn(job_dirs) + 10 > table.getn(dirs) and
    --      table.getn(job_dirs) - 10 < table.getn(dirs) then
    --     in_range = true
    --   end
    --   eq(true, in_range)
    -- end)

    it('with add directories', function()
      local dirs = scan.scan_dir('.', { add_dirs = true })
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { '.', '-I' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    end)

    it('until depth 1 is reached', function()
      local dirs = scan.scan_dir('.', { depth = 1 })
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { '.', '--type', 'f', '--maxdepth', '1', '-I' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    end)

    it('until depth 1 is reached and with directories', function()
      local dirs = scan.scan_dir('.', { depth = 1, add_dirs = true })
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { '.', '--maxdepth', '1', '-I' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    end)

    it('until depth 1 is reached and with directories and hidden', function()
      local dirs = scan.scan_dir('.', { depth = 1, add_dirs = true, hidden = true })
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { '.', '--maxdepth', '1', '--hidden', '-I' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    end)

    it('until depth 2 is reached', function()
      local dirs = scan.scan_dir('.', { depth = 2 })
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { '.', '--type', 'f', '--maxdepth', '2', '-I' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    end)

    it('until depth 3 is reached and with directories and hidden', function()
      local dirs = scan.scan_dir('.', { depth = 3, add_dirs = true, hidden = true })
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { '.', '--maxdepth', '3', '--hidden', '-I' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    end)

    -- TODO(conni2461): Disabled for now. Doesn't work that good anywaay
    -- it('with respect_gitignore', function()
    --   vim.cmd':silent !touch lua/test.so'
    --   local dirs = scan.scan_dir('.', { respect_gitignore = true })
    --   local job_dirs = Job:new({
    --     command = fd_cmd,
    --     args = { '--type', 'f', '.' },
    --     cwd = '.'
    --   }):sync()
    --   vim.cmd':silent !rm lua/test.so'
    --   eq('table', type(dirs))
    --   eq(table.getn(job_dirs), table.getn(dirs))
    --   eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    -- end)

    it('with search pattern', function()
      local dirs = scan.scan_dir('.', { search_pattern = 'scandir' })
      local job_dirs = Job:new({
        command = fd_cmd,
        args = { 'scandir', '--type', 'f', '-I', '.' },
        cwd = '.'
      }):sync()
      eq('table', type(dirs))
      eq(table.getn(job_dirs), table.getn(dirs))
      eq(table.getn(job_dirs), compare_tables(job_dirs, dirs, '.'))
    end)
  end)

  describe('ls', function()
    it('works for cwd', function()
      local dirs = scan.ls('.')
      eq('table', type(dirs))
      eq(true, contains_match(dirs, 'CHANGELOG.md'))
      eq(true, contains_match(dirs, 'LICENSE'))
      eq(true, contains_match(dirs, 'README.md'))
      eq(true, contains_match(dirs, 'lua'))
      eq(false, contains_match(dirs, '%.git$'))
    end)

    it('works for another directory', function()
      local dirs = scan.ls('./lua')
      eq('table', type(dirs))
      eq(true, contains_match(dirs, 'luassert'))
      eq(true, contains_match(dirs, 'plenary'))
      eq(true, contains_match(dirs, 'say.lua'))
      eq(false, contains_match(dirs, 'README.md'))
    end)

    it('works with opts.hidden for cwd', function()
      local dirs = scan.ls('.', { hidden = true })
      eq('table', type(dirs))
      eq(true, contains_match(dirs, 'CHANGELOG.md'))
      eq(true, contains_match(dirs, 'LICENSE'))
      eq(true, contains_match(dirs, 'README.md'))
      eq(true, contains_match(dirs, 'lua'))
      eq(true, contains_match(dirs, '%.git$'))
    end)
  end)
end)
