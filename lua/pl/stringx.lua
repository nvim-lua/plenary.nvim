--- Python-style extended string library.
--
-- see 3.6.1 of the Python reference.
-- If you want to make these available as string methods, then say
-- `stringx.import()` to bring them into the standard `string` table.
--
-- See @{03-strings.md|the Guide}
--
-- Dependencies: `pl.utils`
-- @module pl.stringx
local utils = require 'pl.utils'
local string = string
local find = string.find
local type,setmetatable,ipairs = type,setmetatable,ipairs
local error = error
local gsub = string.gsub
local rep = string.rep
local sub = string.sub
local reverse = string.reverse
local concat = table.concat
local append = table.insert
local escape = utils.escape
local ceil, max = math.ceil, math.max
local assert_arg,usplit = utils.assert_arg,utils.split
local lstrip

local function assert_string (n,s)
    assert_arg(n,s,'string')
end

local function non_empty(s)
    return #s > 0
end

local function assert_nonempty_string(n,s)
    assert_arg(n,s,'string',non_empty,'must be a non-empty string')
end

local function makelist(l)
    return setmetatable(l, require('pl.List'))
end

local stringx = {}

------------------
-- String Predicates
-- @section predicates

--- does s only contain alphabetic characters?
-- @string s a string
function stringx.isalpha(s)
    assert_string(1,s)
    return find(s,'^%a+$') == 1
end

--- does s only contain digits?
-- @string s a string
function stringx.isdigit(s)
    assert_string(1,s)
    return find(s,'^%d+$') == 1
end

--- does s only contain alphanumeric characters?
-- @string s a string
function stringx.isalnum(s)
    assert_string(1,s)
    return find(s,'^%w+$') == 1
end

--- does s only contain spaces?
-- @string s a string
function stringx.isspace(s)
    assert_string(1,s)
    return find(s,'^%s+$') == 1
end

--- does s only contain lower case characters?
-- @string s a string
function stringx.islower(s)
    assert_string(1,s)
    return find(s,'^[%l%s]+$') == 1
end

--- does s only contain upper case characters?
-- @string s a string
function stringx.isupper(s)
    assert_string(1,s)
    return find(s,'^[%u%s]+$') == 1
end

local function raw_startswith(s, prefix)
    return find(s,prefix,1,true) == 1
end

local function raw_endswith(s, suffix)
    return #s >= #suffix and find(s, suffix, #s-#suffix+1, true) and true or false
end

local function test_affixes(s, affixes, fn)
    if type(affixes) == 'string' then
        return fn(s,affixes)
    elseif type(affixes) == 'table' then
        for _,affix in ipairs(affixes) do
            if fn(s,affix) then return true end
        end
        return false
    else
        error(("argument #2 expected a 'string' or a 'table', got a '%s'"):format(type(affixes)))
    end
end

--- does s start with prefix or one of prefixes?
-- @string s a string
-- @param prefix a string or an array of strings
function stringx.startswith(s,prefix)
    assert_string(1,s)
    return test_affixes(s,prefix,raw_startswith)
end

--- does s end with suffix or one of suffixes?
-- @string s a string
-- @param suffix a string or an array of strings
function stringx.endswith(s,suffix)
    assert_string(1,s)
    return test_affixes(s,suffix,raw_endswith)
end

--- Strings and Lists
-- @section lists

--- concatenate the strings using this string as a delimiter.
-- @string s the string
-- @param seq a table of strings or numbers
-- @usage (' '):join {1,2,3} == '1 2 3'
function stringx.join(s,seq)
    assert_string(1,s)
    return concat(seq,s)
end

--- Split a string into a list of lines.
-- `"\r"`, `"\n"`, and `"\r\n"` are considered line ends.
-- They are not included in the lines unless `keepends` is passed.
-- Terminal line end does not produce an extra line.
-- Splitting an empty string results in an empty list.
-- @string s the string.
-- @bool[opt] keep_ends include line ends.
function stringx.splitlines(s, keep_ends)
    assert_string(1, s)
    local res = {}
    local pos = 1
    while true do
        local line_end_pos = find(s, '[\r\n]', pos)
        if not line_end_pos then
            break
        end

        local line_end = sub(s, line_end_pos, line_end_pos)
        if line_end == '\r' and sub(s, line_end_pos + 1, line_end_pos + 1) == '\n' then
            line_end = '\r\n'
        end

        local line = sub(s, pos, line_end_pos - 1)
        if keep_ends then
            line = line .. line_end
        end
        append(res, line)

        pos = line_end_pos + #line_end
    end

    if pos <= #s then
        append(res, sub(s, pos))
    end
    return makelist(res)
end

--- split a string into a list of strings using a delimiter.
-- @function split
-- @string s the string
-- @string[opt] re a delimiter (defaults to whitespace)
-- @int[opt] n maximum number of results
-- @usage #(('one two'):split()) == 2
-- @usage ('one,two,three'):split(',') == List{'one','two','three'}
-- @usage ('one,two,three'):split(',',2) == List{'one','two,three'}
function stringx.split(s,re,n)
    assert_string(1,s)
    local plain = true
    if not re then -- default spaces
        s = lstrip(s)
        plain = false
    end
    local res = usplit(s,re,plain,n)
    if re and re ~= '' and
       find(s,re,-#re,true) and
       (n or math.huge) > #res then
        res[#res+1] = ""
    end
    return makelist(res)
end

--- replace all tabs in s with tabsize spaces. If not specified, tabsize defaults to 8.
-- with 0.9.5 this now correctly expands to the next tab stop (if you really
-- want to just replace tabs, use :gsub('\t','  ') etc)
-- @string s the string
-- @int tabsize[opt=8] number of spaces to expand each tab
function stringx.expandtabs(s,tabsize)
    assert_string(1,s)
    tabsize = tabsize or 8
    return (s:gsub("([^\t\r\n]*)\t", function(before_tab)
        return before_tab .. (" "):rep(tabsize - #before_tab % tabsize)
    end))
end

--- Finding and Replacing
-- @section find

local function _find_all(s,sub,first,last)
    first = first or 1
    last = last or #s
    if sub == '' then return last+1,last-first+1 end
    local i1,i2 = find(s,sub,first,true)
    local res
    local k = 0
    while i1 do
        if last and i2 > last then break end
        res = i1
        k = k + 1
        i1,i2 = find(s,sub,i2+1,true)
    end
    return res,k
end

--- find index of first instance of sub in s from the left.
-- @string s the string
-- @string sub substring
-- @int[opt] first first index
-- @int[opt] last last index
function stringx.lfind(s,sub,first,last)
    assert_string(1,s)
    assert_string(2,sub)
    local i1, i2 = find(s,sub,first,true)

    if i1 and (not last or i2 <= last) then
        return i1
    else
        return nil
    end
end

--- find index of first instance of sub in s from the right.
-- @string s the string
-- @string sub substring
-- @int[opt] first first index
-- @int[opt] last last index
function stringx.rfind(s,sub,first,last)
    assert_string(1,s)
    assert_string(2,sub)
    return (_find_all(s,sub,first,last))
end

--- replace up to n instances of old by new in the string s.
-- if n is not present, replace all instances.
-- @string s the string
-- @string old the target substring
-- @string new the substitution
-- @int[opt] n optional maximum number of substitutions
-- @return result string
function stringx.replace(s,old,new,n)
    assert_string(1,s)
    assert_string(2,old)
    assert_string(3,new)
    return (gsub(s,escape(old),new:gsub('%%','%%%%'),n))
end

--- count all instances of substring in string.
-- @string s the string
-- @string sub substring
function stringx.count(s,sub)
    assert_string(1,s)
    local _,k = _find_all(s,sub,1)
    return k
end

--- Stripping and Justifying
-- @section strip

local function _just(s,w,ch,left,right)
    local n = #s
    if w > n then
        if not ch then ch = ' ' end
        local f1,f2
        if left and right then
            local rn = ceil((w-n)/2)
            local ln = w - n - rn
            f1 = rep(ch,ln)
            f2 = rep(ch,rn)
        elseif right then
            f1 = rep(ch,w-n)
            f2 = ''
        else
            f2 = rep(ch,w-n)
            f1 = ''
        end
        return f1..s..f2
    else
        return s
    end
end

--- left-justify s with width w.
-- @string s the string
-- @int w width of justification
-- @string[opt=' '] ch padding character
function stringx.ljust(s,w,ch)
    assert_string(1,s)
    assert_arg(2,w,'number')
    return _just(s,w,ch,true,false)
end

--- right-justify s with width w.
-- @string s the string
-- @int w width of justification
-- @string[opt=' '] ch padding character
function stringx.rjust(s,w,ch)
    assert_string(1,s)
    assert_arg(2,w,'number')
    return _just(s,w,ch,false,true)
end

--- center-justify s with width w.
-- @string s the string
-- @int w width of justification
-- @string[opt=' '] ch padding character
function stringx.center(s,w,ch)
    assert_string(1,s)
    assert_arg(2,w,'number')
    return _just(s,w,ch,true,true)
end

local function _strip(s,left,right,chrs)
    if not chrs then
        chrs = '%s'
    else
        chrs = '['..escape(chrs)..']'
    end
    local f = 1
    local t
    if left then
        local i1,i2 = find(s,'^'..chrs..'*')
        if i2 >= i1 then
            f = i2+1
        end
    end
    if right then
        if #s < 200 then
            local i1,i2 = find(s,chrs..'*$',f)
            if i2 >= i1 then
                t = i1-1
            end
        else
            local rs = reverse(s)
            local i1,i2 = find(rs, '^'..chrs..'*')
            if i2 >= i1 then
                t = -i2
            end
        end
    end
    return sub(s,f,t)
end

--- trim any whitespace on the left of s.
-- @string s the string
-- @string[opt='%s'] chrs default any whitespace character,
--  but can be a string of characters to be trimmed
function stringx.lstrip(s,chrs)
    assert_string(1,s)
    return _strip(s,true,false,chrs)
end
lstrip = stringx.lstrip

--- trim any whitespace on the right of s.
-- @string s the string
-- @string[opt='%s'] chrs default any whitespace character,
--  but can be a string of characters to be trimmed
function stringx.rstrip(s,chrs)
    assert_string(1,s)
    return _strip(s,false,true,chrs)
end

--- trim any whitespace on both left and right of s.
-- @string s the string
-- @string[opt='%s'] chrs default any whitespace character,
--  but can be a string of characters to be trimmed
function stringx.strip(s,chrs)
    assert_string(1,s)
    return _strip(s,true,true,chrs)
end

--- Partioning Strings
-- @section partioning

--- split a string using a pattern. Note that at least one value will be returned!
-- @string s the string
-- @string[opt='%s'] re a Lua string pattern (defaults to whitespace)
-- @return the parts of the string
-- @usage  a,b = line:splitv('=')
function stringx.splitv(s,re)
    assert_string(1,s)
    return utils.splitv(s,re)
end

-- The partition functions split a string  using a delimiter into three parts:
-- the part before, the delimiter itself, and the part afterwards
local function _partition(p,delim,fn)
    local i1,i2 = fn(p,delim)
    if not i1 or i1 == -1 then
        return p,'',''
    else
        if not i2 then i2 = i1 end
        return sub(p,1,i1-1),sub(p,i1,i2),sub(p,i2+1)
    end
end

--- partition the string using first occurance of a delimiter
-- @string s the string
-- @string ch delimiter
-- @return part before ch
-- @return ch
-- @return part after ch
function stringx.partition(s,ch)
    assert_string(1,s)
    assert_nonempty_string(2,ch)
    return _partition(s,ch,stringx.lfind)
end

--- partition the string p using last occurance of a delimiter
-- @string s the string
-- @string ch delimiter
-- @return part before ch
-- @return ch
-- @return part after ch
function stringx.rpartition(s,ch)
    assert_string(1,s)
    assert_nonempty_string(2,ch)
    local a,b,c = _partition(s,ch,stringx.rfind)
    if a == s then -- no match found
        return c,b,a
    end
    return a,b,c
end

--- return the 'character' at the index.
-- @string s the string
-- @int idx an index (can be negative)
-- @return a substring of length 1 if successful, empty string otherwise.
function stringx.at(s,idx)
    assert_string(1,s)
    assert_arg(2,idx,'number')
    return sub(s,idx,idx)
end

--- Miscelaneous
-- @section misc

--- return an iterator over all lines in a string
-- @string s the string
-- @return an iterator
function stringx.lines(s)
    assert_string(1,s)
    if not s:find '\n$' then s = s..'\n' end
    return s:gmatch('([^\n]*)\n')
end

--- iniital word letters uppercase ('title case').
-- Here 'words' mean chunks of non-space characters.
-- @string s the string
-- @return a string with each word's first letter uppercase
function stringx.title(s)
    assert_string(1,s)
    return (s:gsub('(%S)(%S*)',function(f,r)
        return f:upper()..r:lower()
    end))
end

stringx.capitalize = stringx.title

local ellipsis = '...'
local n_ellipsis = #ellipsis

--- Return a shortened version of a string.
-- Fits string within w characters. Removed characters are marked with ellipsis.
-- @string s the string
-- @int w the maxinum size allowed
-- @bool tail true if we want to show the end of the string (head otherwise)
-- @usage ('1234567890'):shorten(8) == '12345...'
-- @usage ('1234567890'):shorten(8, true) == '...67890'
-- @usage ('1234567890'):shorten(20) == '1234567890'
function stringx.shorten(s,w,tail)
    assert_string(1,s)
    if #s > w then
        if w < n_ellipsis then return ellipsis:sub(1,w) end
        if tail then
            local i = #s - w + 1 + n_ellipsis
            return ellipsis .. s:sub(i)
        else
            return s:sub(1,w-n_ellipsis) .. ellipsis
        end
    end
    return s
end

--- Utility function that finds any patterns that match a long string's an open or close.
-- Note that having this function use the least number of equal signs that is possible is a harder algorithm to come up with.
-- Right now, it simply returns the greatest number of them found.
-- @param s The string
-- @return 'nil' if not found. If found, the maximum number of equal signs found within all matches.
local function has_lquote(s)
    local lstring_pat = '([%[%]])(=*)%1'
    local equals, new_equals, _
    local finish = 1
    repeat
        _, finish, _, new_equals = s:find(lstring_pat, finish)
        if new_equals then
            equals = max(equals or 0, #new_equals)
        end
    until not new_equals

    return equals
end

--- Quote the given string and preserve any control or escape characters, such that reloading the string in Lua returns the same result.
-- @param s The string to be quoted.
-- @return The quoted string.
function stringx.quote_string(s)
    assert_string(1,s)
    -- Find out if there are any embedded long-quote sequences that may cause issues.
    -- This is important when strings are embedded within strings, like when serializing.
    -- Append a closing bracket to catch unfinished long-quote sequences at the end of the string.
    local equal_signs = has_lquote(s .. "]")

    -- Note that strings containing "\r" can't be quoted using long brackets
    -- as Lua lexer converts all newlines to "\n" within long strings.
    if (s:find("\n") or equal_signs) and not s:find("\r") then
        -- If there is an embedded sequence that matches a long quote, then
        -- find the one with the maximum number of = signs and add one to that number.
        equal_signs = ("="):rep((equal_signs or -1) + 1)
        -- Long strings strip out leading newline. We want to retain that, when quoting.
        if s:find("^\n") then s = "\n" .. s end
        local lbracket, rbracket =
            "[" .. equal_signs .. "[",
            "]" .. equal_signs .. "]"
        s = lbracket .. s .. rbracket
    else
        -- Escape funny stuff. Lua 5.1 does not handle "\r" correctly.
        s = ("%q"):format(s):gsub("\r", "\\r")
    end
    return s
end

function stringx.import()
    utils.import(stringx,string)
end

return stringx
