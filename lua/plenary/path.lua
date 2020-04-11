--- Path.lua
---
--- Goal: Create objects that are extremely similar to Python's `Path` Objects.
--- Reference: https://docs.python.org/3/library/pathlib.html

local vim = vim

local path = {}

path.__index = path

path.__div = function(self, other)
    assert(path.is_path(self))
    assert(path.is_path(other))

    return self:joinpath(other)
end

path.__tostring = function(self)
    return self.raw
end

path.is_path = function(a)
    return getmetatable(a) == path
end

-- TODO: check for windows
path._sep = "/"

function path:new(path_input)
    -- If we already have a path, it's fine.
    --   Just return it
    if path.is_path(path_input) then
        return path_input
    end


    local path_string
    if vim.tbl_islist(path_input) then
        path_string = table.concat(path_input, path._sep)
    else
        assert(type(path_input) == 'string')
        path_string = path_input
    end

    -- TODO: Should probably remove and dumb stuff like double seps, periods in the middle, etc.

    local obj = {
        raw=path_string,

        _absolute=nil,
    }

    setmetatable(obj, path)

    return obj
end

function path:joinpath(path_string)
    -- TODO: This should not just concat these.
    return path.new(self.raw .. path._sep .. path_string)
end

function path:absolute()
    if self._absolute == nil then
        -- NOTE: I can see a potential bug here in the fact that
        --   I'm not sure how we know if we've got the right cwd to do this.
        --   So maybe at some point we'll have to cache the cwd when we create the path.
        self._absolute = vim.fn.fnamemodify(self.raw, ":p")
    end

    return self._absolute
end

function path:exists()
    return vim.fn.filereadable(self.absolute())
end

function path:is_dir()
    return vim.fn.isdirectory(self.absolute())
end


return path
