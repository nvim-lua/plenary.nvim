-- dont edit this file, it was generated
local tbl = require('plenary/tbl')

local function rotate2(A0, A1) return A1, A0 end

local function rotate3(A0, A1, A2) return A1, A2, A0 end

local function rotate4(A0, A1, A2, A3) return A1, A2, A3, A0 end

local function rotate5(A0, A1, A2, A3, A4) return A1, A2, A3, A4, A0 end

local function rotate6(A0, A1, A2, A3, A4, A5) return A1, A2, A3, A4, A5, A0 end

local function rotate7(A0, A1, A2, A3, A4, A5, A6)
    return A1, A2, A3, A4, A5, A6, A0
end

local function rotate8(A0, A1, A2, A3, A4, A5, A6, A7)
    return A1, A2, A3, A4, A5, A6, A7, A0
end

local function rotate9(A0, A1, A2, A3, A4, A5, A6, A7, A8)
    return A1, A2, A3, A4, A5, A6, A7, A8, A0
end

local function rotate10(A0, A1, A2, A3, A4, A5, A6, A7, A8, A9)
    return A1, A2, A3, A4, A5, A6, A7, A8, A9, A0
end

local function rotate11(A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10)
    return A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A0
end

local function rotate12(A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11)
    return A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A0
end

local function rotate13(A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12)
    return A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A0
end

local function rotate14(A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12,
                        A13)
    return A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A0
end

local function rotate15(A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12,
                        A13, A14)
    return A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A14, A0
end

local function rotate_n(first, ...)
    local args = tbl.pack(...)
    args[#args + 1] = first
    return tbl.unpack(args)
end

local function rotate(...)
    local nargs = select('#', ...)

    if nargs == 1 then return ... end

    if nargs == 2 then return rotate2(...) end

    if nargs == 3 then return rotate3(...) end

    if nargs == 4 then return rotate4(...) end

    if nargs == 5 then return rotate5(...) end

    if nargs == 6 then return rotate6(...) end

    if nargs == 7 then return rotate7(...) end

    if nargs == 8 then return rotate8(...) end

    if nargs == 9 then return rotate9(...) end

    if nargs == 10 then return rotate10(...) end

    if nargs == 11 then return rotate11(...) end

    if nargs == 12 then return rotate12(...) end

    if nargs == 13 then return rotate13(...) end

    if nargs == 14 then return rotate14(...) end

    if nargs == 15 then return rotate15(...) end

    return rotate_n(...)
end

return {rotate = rotate}
