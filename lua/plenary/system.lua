local system = {}

function system.is_windows()
    -- The shellslash option is not able to change this variable
    if package.config:sub(1,1) == "\\" then
        return true
    end

    return false
end

function system.uses_shellslash()
    local shellslash_exists = vim.fn.exists("+shellslash") ~= 0

    if shellslash_exists then
        return vim.o.shellslash
    end

    return false
end

return system
