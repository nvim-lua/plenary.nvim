--- Generally useful routines.
-- See  @{01-introduction.md.Generally_useful_functions|the Guide}.
--
-- Dependencies: `pl.compat`, all exported fields and functions from
-- `pl.compat` are also available in this module.
--
-- @module pl.utils
local format = string.format
local compat = require 'pl.compat'
local stdout = io.stdout
local append = table.insert
local _unpack = table.unpack  -- always injected by 'compat'

local is_windows = compat.is_windows
local err_mode = 'default'
local raise
local operators
local _function_factories = {}


local utils = { _VERSION = "1.7.0" }
for k, v in pairs(compat) do utils[k] = v  end

--- Some standard patterns
-- @table patterns
utils.patterns = {
    FLOAT = '[%+%-%d]%d*%.?%d*[eE]?[%+%-]?%d*', -- floating point number
    INTEGER = '[+%-%d]%d*',                     -- integer number
    IDEN = '[%a_][%w_]*',                       -- identifier
    FILE = '[%a%.\\][:%][%w%._%-\\]*',          -- file
}


--- Standard meta-tables as used by other Penlight modules
-- @table stdmt
-- @field List the List metatable
-- @field Map the Map metatable
-- @field Set the Set metatable
-- @field MultiMap the MultiMap metatable
utils.stdmt = {
    List = {_name='List'},
    Map = {_name='Map'},
    Set = {_name='Set'},
    MultiMap = {_name='MultiMap'},
}


--- pack an argument list into a table.
-- @param ... any arguments
-- @return a table with field `n` set to the length
-- @function utils.pack
-- @see compat.pack
utils.pack = table.pack  -- added here to be symmetrical with unpack

--- unpack a table and return its contents.
--
-- NOTE: this implementation differs from the Lua implementation in the way
-- that this one DOES honor the `n` field in the table `t`, such that it is 'nil-safe'.
-- @param t table to unpack
-- @param[opt] i index from which to start unpacking, defaults to 1
-- @param[opt] t index of the last element to unpack, defaults to `t.n` or `#t`
-- @return multiple return values from the table
-- @function utils.unpack
-- @see compat.unpack
-- @usage
-- local t = table.pack(nil, nil, nil, 4)
-- local a, b, c, d = table.unpack(t)   -- this `unpack` is NOT nil-safe, so d == nil
--
-- local a, b, c, d = utils.unpack(t)   -- this is nil-safe, so d == 4
function utils.unpack(t, i, j)
    return _unpack(t, i or 1, j or t.n or #t)
end

--- print an arbitrary number of arguments using a format.
-- Output will be sent to `stdout`.
-- @param fmt The format (see `string.format`)
-- @param ... Extra arguments for format
function utils.printf(fmt, ...)
    utils.assert_string(1, fmt)
    utils.fprintf(stdout, fmt, ...)
end

--- write an arbitrary number of arguments to a file using a format.
-- @param f File handle to write to.
-- @param fmt The format (see `string.format`).
-- @param ... Extra arguments for format
function utils.fprintf(f,fmt,...)
    utils.assert_string(2,fmt)
    f:write(format(fmt,...))
end

do
    local function import_symbol(T,k,v,libname)
        local key = rawget(T,k)
        -- warn about collisions!
        if key and k ~= '_M' and k ~= '_NAME' and k ~= '_PACKAGE' and k ~= '_VERSION' then
            utils.fprintf(io.stderr,"warning: '%s.%s' will not override existing symbol\n",libname,k)
            return
        end
        rawset(T,k,v)
    end

    local function lookup_lib(T,t)
        for k,v in pairs(T) do
            if v == t then return k end
        end
        return '?'
    end

    local already_imported = {}

    --- take a table and 'inject' it into the local namespace.
    -- @param t The table (table), or module name (string), defaults to this `utils` module table
    -- @param T An optional destination table (defaults to callers environment)
    function utils.import(t,T)
        T = T or _G
        t = t or utils
        if type(t) == 'string' then
            t = require (t)
        end
        local libname = lookup_lib(T,t)
        if already_imported[t] then return end
        already_imported[t] = libname
        for k,v in pairs(t) do
            import_symbol(T,k,v,libname)
        end
    end
end

--- return either of two values, depending on a condition.
-- @param cond A condition
-- @param value1 Value returned if cond is truthy
-- @param value2 Value returned if cond is falsy
function utils.choose(cond, value1, value2)
    return cond and value1 or value2
end

--- convert an array of values to strings.
-- @param t a list-like table
-- @param[opt] temp (table) buffer to use, otherwise allocate
-- @param[opt] tostr custom tostring function, called with (value,index). Defaults to `tostring`.
-- @return the converted buffer
function utils.array_tostring (t,temp,tostr)
    temp, tostr = temp or {}, tostr or tostring
    for i = 1,#t do
        temp[i] = tostr(t[i],i)
    end
    return temp
end



--- is the object of the specified type?
-- If the type is a string, then use type, otherwise compare with metatable
-- @param obj An object to check
-- @param tp String of what type it should be
-- @return boolean
-- @usage utils.is_type("hello world", "string")   --> true
-- -- or check metatable
-- local my_mt = {}
-- local my_obj = setmetatable(my_obj, my_mt)
-- utils.is_type(my_obj, my_mt)  --> true
function utils.is_type (obj,tp)
    if type(tp) == 'string' then return type(obj) == tp end
    local mt = getmetatable(obj)
    return tp == mt
end

--- Error handling
-- @section Error-handling

--- assert that the given argument is in fact of the correct type.
-- @param n argument index
-- @param val the value
-- @param tp the type
-- @param verify an optional verification function
-- @param msg an optional custom message
-- @param lev optional stack position for trace, default 2
-- @return the validated value
-- @raise if `val` is not the correct type
-- @usage
-- local param1 = assert_arg(1,"hello",'table')  --> error: argument 1 expected a 'table', got a 'string'
-- local param4 = assert_arg(4,'!@#$%^&*','string',path.isdir,'not a directory')
--      --> error: argument 4: '!@#$%^&*' not a directory
function utils.assert_arg (n,val,tp,verify,msg,lev)
    if type(val) ~= tp then
        error(("argument %d expected a '%s', got a '%s'"):format(n,tp,type(val)),lev or 2)
    end
    if verify and not verify(val) then
        error(("argument %d: '%s' %s"):format(n,val,msg),lev or 2)
    end
    return val
end

--- process a function argument.
-- This is used throughout Penlight and defines what is meant by a function:
-- Something that is callable, or an operator string as defined by <code>pl.operator</code>,
-- such as '>' or '#'. If a function factory has been registered for the type, it will
-- be called to get the function.
-- @param idx argument index
-- @param f a function, operator string, or callable object
-- @param msg optional error message
-- @return a callable
-- @raise if idx is not a number or if f is not callable
function utils.function_arg (idx,f,msg)
    utils.assert_arg(1,idx,'number')
    local tp = type(f)
    if tp == 'function' then return f end  -- no worries!
    -- ok, a string can correspond to an operator (like '==')
    if tp == 'string' then
        if not operators then operators = require 'pl.operator'.optable end
        local fn = operators[f]
        if fn then return fn end
        local fn, err = utils.string_lambda(f)
        if not fn then error(err..': '..f) end
        return fn
    elseif tp == 'table' or tp == 'userdata' then
        local mt = getmetatable(f)
        if not mt then error('not a callable object',2) end
        local ff = _function_factories[mt]
        if not ff then
            if not mt.__call then error('not a callable object',2) end
            return f
        else
            return ff(f) -- we have a function factory for this type!
        end
    end
    if not msg then msg = " must be callable" end
    if idx > 0 then
        error("argument "..idx..": "..msg,2)
    else
        error(msg,2)
    end
end


--- assert the common case that the argument is a string.
-- @param n argument index
-- @param val a value that must be a string
-- @return the validated value
-- @raise val must be a string
-- @usage
-- local val = 42
-- local param2 = utils.assert_string(2, val) --> error: argument 2 expected a 'string', got a 'number'
function utils.assert_string (n, val)
    return utils.assert_arg(n,val,'string',nil,nil,3)
end

--- control the error strategy used by Penlight.
-- This is a global setting that controls how `utils.raise` behaves:
--
-- - 'default': return `nil + error` (this is the default)
-- - 'error': throw a Lua error
-- - 'quit': exit the program
--
-- @param mode either 'default', 'quit'  or 'error'
-- @see utils.raise
function utils.on_error (mode)
    mode = tostring(mode)
    if ({['default'] = 1, ['quit'] = 2, ['error'] = 3})[mode] then
      err_mode = mode
    else
      -- fail loudly
      local err = "Bad argument expected string; 'default', 'quit', or 'error'. Got '"..tostring(mode).."'"
      if err_mode == 'default' then
        error(err, 2)  -- even in 'default' mode fail loud in this case
      end
      raise(err)
    end
end

--- used by Penlight functions to return errors. Its global behaviour is controlled
-- by `utils.on_error`.
-- To use this function you MUST use it in conjunction with `return`, since it might
-- return `nil + error`.
-- @param err the error string.
-- @see utils.on_error
-- @usage
-- if some_condition then
--   return utils.raise("some condition was not met")  -- MUST use 'return'!
-- end
function utils.raise (err)
    if err_mode == 'default' then
        return nil, err
    elseif err_mode == 'quit' then
        return utils.quit(err)
    else
        error(err, 2)
    end
end
raise = utils.raise



--- File handling
-- @section files

--- return the contents of a file as a string
-- @param filename The file path
-- @param is_bin open in binary mode
-- @return file contents
function utils.readfile(filename,is_bin)
    local mode = is_bin and 'b' or ''
    utils.assert_string(1,filename)
    local f,open_err = io.open(filename,'r'..mode)
    if not f then return raise (open_err) end
    local res,read_err = f:read('*a')
    f:close()
    if not res then
        -- Errors in io.open have "filename: " prefix,
        -- error in file:read don't, add it.
        return raise (filename..": "..read_err)
    end
    return res
end

--- write a string to a file
-- @param filename The file path
-- @param str The string
-- @param is_bin open in binary mode
-- @return true or nil
-- @return error message
-- @raise error if filename or str aren't strings
function utils.writefile(filename,str,is_bin)
    local mode = is_bin and 'b' or ''
    utils.assert_string(1,filename)
    utils.assert_string(2,str)
    local f,err = io.open(filename,'w'..mode)
    if not f then return raise(err) end
    local ok, write_err = f:write(str)
    f:close()
    if not ok then
        -- Errors in io.open have "filename: " prefix,
        -- error in file:write don't, add it.
        return raise (filename..": "..write_err)
    end
    return true
end

--- return the contents of a file as a list of lines
-- @param filename The file path
-- @return file contents as a table
-- @raise error if filename is not a string
function utils.readlines(filename)
    utils.assert_string(1,filename)
    local f,err = io.open(filename,'r')
    if not f then return raise(err) end
    local res = {}
    for line in f:lines() do
        append(res,line)
    end
    f:close()
    return res
end

--- OS functions
-- @section OS-functions

--- execute a shell command and return the output.
-- This function redirects the output to tempfiles and returns the content of those files.
-- @param cmd a shell command
-- @param bin boolean, if true, read output as binary file
-- @return true if successful
-- @return actual return code
-- @return stdout output (string)
-- @return errout output (string)
function utils.executeex(cmd, bin)
    local outfile = os.tmpname()
    local errfile = os.tmpname()

    if is_windows and not outfile:find(':') then
        outfile = os.getenv('TEMP')..outfile
        errfile = os.getenv('TEMP')..errfile
    end
    cmd = cmd .. " > " .. utils.quote_arg(outfile) .. " 2> " .. utils.quote_arg(errfile)

    local success, retcode = utils.execute(cmd)
    local outcontent = utils.readfile(outfile, bin)
    local errcontent = utils.readfile(errfile, bin)
    os.remove(outfile)
    os.remove(errfile)
    return success, retcode, (outcontent or ""), (errcontent or "")
end

--- Quote and escape an argument of a command.
-- Quotes a single (or list of) argument(s) of a command to be passed
-- to `os.execute`, `pl.utils.execute` or `pl.utils.executeex`.
-- @param argument (string or table/list) the argument to quote. If a list then
-- all arguments in the list will be returned as a single string quoted.
-- @return quoted and escaped argument.
-- @usage
-- local options = utils.quote_arg {
--     "-lluacov",
--     "-e",
--     "utils = print(require('pl.utils')._VERSION",
-- }
-- -- returns: -lluacov -e 'utils = print(require('\''pl.utils'\'')._VERSION'
function utils.quote_arg(argument)
    if type(argument) == "table" then
        -- encode an entire table
        local r = {}
        for i, arg in ipairs(argument) do
            r[i] = utils.quote_arg(arg)
        end

        return table.concat(r, " ")
    end
    -- only a single argument
    if is_windows then
        if argument == "" or argument:find('[ \f\t\v]') then
            -- Need to quote the argument.
            -- Quotes need to be escaped with backslashes;
            -- additionally, backslashes before a quote, escaped or not,
            -- need to be doubled.
            -- See documentation for CommandLineToArgvW Windows function.
            argument = '"' .. argument:gsub([[(\*)"]], [[%1%1\"]]):gsub([[\+$]], "%0%0") .. '"'
        end

        -- os.execute() uses system() C function, which on Windows passes command
        -- to cmd.exe. Escape its special characters.
        return (argument:gsub('["^<>!|&%%]', "^%0"))
    else
        if argument == "" or argument:find('[^a-zA-Z0-9_@%+=:,./-]') then
            -- To quote arguments on posix-like systems use single quotes.
            -- To represent an embedded single quote close quoted string ('),
            -- add escaped quote (\'), open quoted string again (').
            argument = "'" .. argument:gsub("'", [['\'']]) .. "'"
        end

        return argument
    end
end

--- error out of this program gracefully.
-- @param[opt] code The exit code, defaults to -`1` if omitted
-- @param msg The exit message will be sent to `stderr` (will be formatted with the extra parameters)
-- @param ... extra arguments for message's format'
-- @see utils.fprintf
-- @usage utils.quit(-1, "Error '%s' happened", "42")
-- -- is equivalent to
-- utils.quit("Error '%s' happened", "42")  --> Error '42' happened
function utils.quit(code, msg, ...)
    if type(code) == 'string' then
        utils.fprintf(io.stderr, code, msg, ...)
        io.stderr:write('\n')
        code = -1 -- TODO: this is odd, see the test. Which returns 255 as exit code
    elseif msg then
        utils.fprintf(io.stderr, msg, ...)
        io.stderr:write('\n')
    end
    os.exit(code, true)
end


--- String functions
-- @section string-functions

--- escape any Lua 'magic' characters in a string
-- @param s The input string
function utils.escape(s)
    utils.assert_string(1,s)
    return (s:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1'))
end

--- split a string into a list of strings separated by a delimiter.
-- @param s The input string
-- @param re A Lua string pattern; defaults to '%s+'
-- @param plain don't use Lua patterns
-- @param n optional maximum number of splits
-- @return a list-like table
-- @raise error if s is not a string
function utils.split(s,re,plain,n)
    utils.assert_string(1,s)
    local find,sub,append = string.find, string.sub, table.insert
    local i1,ls = 1,{}
    if not re then re = '%s+' end
    if re == '' then return {s} end
    while true do
        local i2,i3 = find(s,re,i1,plain)
        if not i2 then
            local last = sub(s,i1)
            if last ~= '' then append(ls,last) end
            if #ls == 1 and ls[1] == '' then
                return {}
            else
                return ls
            end
        end
        append(ls,sub(s,i1,i2-1))
        if n and #ls == n then
            ls[#ls] = sub(s,i1)
            return ls
        end
        i1 = i3+1
    end
end

--- split a string into a number of return values.
-- @param s the string
-- @param re the delimiter, default space
-- @return n values
-- @usage first,next = splitv('jane:doe',':')
-- @see split
function utils.splitv (s,re)
    return _unpack(utils.split(s,re))
end


--- Functional
-- @section functional


--- 'memoize' a function (cache returned value for next call).
-- This is useful if you have a function which is relatively expensive,
-- but you don't know in advance what values will be required, so
-- building a table upfront is wasteful/impossible.
-- @param func a function of at least one argument
-- @return a function with at least one argument, which is used as the key.
function utils.memoize(func)
    local cache = {}
    return function(k)
        local res = cache[k]
        if res == nil then
            res = func(k)
            cache[k] = res
        end
        return res
    end
end


--- associate a function factory with a type.
-- A function factory takes an object of the given type and
-- returns a function for evaluating it
-- @tab mt metatable
-- @func fun a callable that returns a function
function utils.add_function_factory (mt,fun)
    _function_factories[mt] = fun
end

local function _string_lambda(f)
    if f:find '^|' or f:find '_' then
        local args,body = f:match '|([^|]*)|(.+)'
        if f:find '_' then
            args = '_'
            body = f
        else
            if not args then return raise 'bad string lambda' end
        end
        local fstr = 'return function('..args..') return '..body..' end'
        local fn,err = utils.load(fstr)
        if not fn then return raise(err) end
        fn = fn()
        return fn
    else
        return raise 'not a string lambda'
    end
end

--- an anonymous function as a string. This string is either of the form
-- '|args| expression' or is a function of one argument, '_'
-- @param lf function as a string
-- @return a function
-- @function utils.string_lambda
-- @usage
-- string_lambda '|x|x+1' (2) == 3
-- string_lambda '_+1' (2) == 3
utils.string_lambda = utils.memoize(_string_lambda)


--- bind the first argument of the function to a value.
-- @param fn a function of at least two values (may be an operator string)
-- @param p a value
-- @return a function such that f(x) is fn(p,x)
-- @raise same as @{function_arg}
-- @see func.bind1
-- @usage local function f(msg, name)
--   print(msg .. " " .. name)
-- end
--
-- local hello = utils.bind1(f, "Hello")
--
-- print(hello("world"))     --> "Hello world"
-- print(hello("sunshine"))  --> "Hello sunshine"
function utils.bind1 (fn,p)
    fn = utils.function_arg(1,fn)
    return function(...) return fn(p,...) end
end

--- bind the second argument of the function to a value.
-- @param fn a function of at least two values (may be an operator string)
-- @param p a value
-- @return a function such that f(x) is fn(x,p)
-- @raise same as @{function_arg}
-- @usage local function f(a, b, c)
--   print(a .. " " .. b .. " " .. c)
-- end
--
-- local hello = utils.bind1(f, "world")
--
-- print(hello("Hello", "!"))  --> "Hello world !"
-- print(hello("Bye", "?"))    --> "Bye world ?"
function utils.bind2 (fn,p)
    fn = utils.function_arg(1,fn)
    return function(x,...) return fn(x,p,...) end
end

return utils


