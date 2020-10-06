--- Path.lua
---
--- Goal: Create objects that are extremely similar to Python's `Path` Objects.
--- Reference: https://docs.python.org/3/library/pathlib.html

local uv = vim.loop

local path = {}

path.__index = path

-- TODO: Could use this to not have to call new... not sure
-- path.__call = path:new

path.__div = function(self, other)
    assert(path.is_path(self))
    assert(path.is_path(other) or type(other) == 'string')

    return self:joinpath(other)
end

path.__tostring = function(self)
    return self.filename
end

-- TODO: See where we concat the table, and maybe we could make this work.
path.__concat = function(self, other)
    print(self, other)
    return self.filename .. other
end

path.is_path = function(a)
    return getmetatable(a) == path
end

-- TODO: check for windows
path._sep = "/"

function path:new(...)
    local args = {...}

    if type(self) == 'string' then
        table.insert(args, 1, self)
        self = path
    end

    local path_input
    if #args == 1 then
        path_input = args[1]
    else
        path_input = args
    end

    -- If we already have a path, it's fine.
    --   Just return it
    if path.is_path(path_input) then
        return path_input
    end


    local path_string
    if vim.tbl_islist(path_input) then
        -- TODO: It's possible this could be done more elegantly with __concat
        --       But I'm unsure of what we'd do to make that happen
        local path_objs = {}
        for _, v in ipairs(path_input) do
            if path.is_path(v) then
                table.insert(path_objs, v.filename)
            else
                assert(type(v) == 'string')
                table.insert(path_objs, v)
            end
        end

        path_string = table.concat(path_objs, path._sep)
    else
        assert(type(path_input) == 'string')
        path_string = path_input
    end

    -- TODO: Should probably remove and dumb stuff like double seps, periods in the middle, etc.

    local obj = {
        filename = path_string,


        _absolute=nil,
    }

    setmetatable(obj, path)

    return obj
end

function path:joinpath(...)
    return path:new(self.filename, ...)
end

function path:absolute()
    if self._absolute == nil then
        -- NOTE: I can see a potential bug here in the fact that
        --   I'm not sure how we know if we've got the right cwd to do this.
        --   So maybe at some point we'll have to cache the cwd when we create the path.
        self._absolute = vim.fn.fnamemodify(self.filename, ":p")
    end

    return self._absolute
end

function path:exists()
    return vim.fn.filereadable(self:absolute()) == 1 or self:is_dir()
end

function path:mkdir(mode, parents, exists_ok)
    mode = mode or 448 -- 0700 -> decimal

    if parents == nil then
        parents = true
    end

    if exists_ok == nil then
        exists_ok = true
    end

    local vim_fn_path = ""
    if parents then
        vim_fn_path = "p"
    end

    return vim.fn.mkdir(self:absolute(), vim_fn_path, mode)
end

function path:rmdir()
    if not self:exists() then
        return
    end

    uv.fs_rmdir(self:absolute())
end

function path:is_dir()
    return vim.fn.isdirectory(self:absolute()) == 1
end

-- TODO:
--  Maybe I can use libuv for this?
function path:open()
end

function path:close()
end

function path:read()
  local fd = assert(uv.fs_open(self:absolute(), "r", 438))
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0))
  assert(uv.fs_close(fd))

  return data
end

function path:readlines()
  local data = self:read()

  data = data:gsub("\r", "")
  return vim.split(data, "\n")
end

return path
