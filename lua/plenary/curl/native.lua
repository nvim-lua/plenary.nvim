local callbacks = {
  ['write_callback'] = function(ffi, clib)
    return function(data, size, nmemb, userp)
      local realsize = size * nmemb
      local mem = ffi.cast("memory *", userp)
      local ptr = clib.realloc(mem.response, mem.size + realsize + 1)

      -- Maybe we can just write in an array of strings
      if not ptr then error("realloc failed :(") end

      mem.response = ptr
      ffi.copy(mem.response, data, realsize)
      mem.size = mem.size + realsize
      mem.response[mem.size] = 0

      return realsize
    end
  end
}

local gen_callback = function(name, ffi, clib)
  return callbacks[name](ffi, clib)
end

-- TODO(conni2461): Maybe move inside run_wrapper?
-- TODO(conni2461): Maybe do error handling as well?
-- TODO(conni2461): Should we error out if not handle. Probably yes!
local curl_easy_setup = function(clib, ...)
  local varargs = {...}
  local url = varargs[1]
  local opts = varargs[2]

  local handle = clib.curl_easy_init()
  if not handle then
    error("We couldn't get a handle from `curl_easy_init`.")
  end
  return handle, url, opts
end

local get_func = function(ffi, clib, ...)
  local handle, url, opts = curl_easy_setup(clib, ...)
  print(vim.inspect(opts))

  local chunk = ffi.new('memory')
  local write_callback = ffi.cast('curl_write_callback', gen_callback('write_callback', ffi, clib))

  clib.curl_easy_setopt(handle, 10002, url) -- CURLOPT_URL
  clib.curl_easy_setopt(handle, 20011, write_callback) -- CURLOPT_WRITEFUNCTION
  clib.curl_easy_setopt(handle, 10001, chunk) -- CRULOPT_WRITEDATA

  -- TODO(conni2461): Handle all result codes
  print(clib.curl_easy_perform(handle))
  local http_code = ffi.new('long [1]')
  clib.curl_easy_getinfo(handle, 2097154, http_code) -- CURLINFO_RESPONSE_CODE

  clib.curl_easy_cleanup(handle)
  return {
    status = tonumber(http_code[0]),
    body = ffi.string(chunk.response)
  }
end

local function native_init()
  local ffi = require'ffi'

  local clib = ffi.load('libcurl')

  ffi.cdef [[
    /* misc */
    void *realloc(void*, size_t);

    typedef struct {
      char *response;
      size_t size;
    } memory;

    /* curl.h */
    typedef void CURL;

    /* flags for init */
    /*
    #define CURL_GLOBAL_SSL (1<<0)
    #define CURL_GLOBAL_WIN32 (1<<1)
    #define CURL_GLOBAL_ALL (CURL_GLOBAL_SSL|CURL_GLOBAL_WIN32)
    #define CURL_GLOBAL_NOTHING 0
    #define CURL_GLOBAL_DEFAULT CURL_GLOBAL_ALL
    #define CURL_GLOBAL_ACK_EINTR (1<<2)
    */

    typedef int CURLoption; /* These are actually enums but we handle them in lua */
    typedef int CURLcode;   /* These are actually enums but we handle them in lua */
    typedef int CURLINFO;   /* These are actually enums but we handle them in lua */
    char *curl_version(void);
    CURLcode curl_global_init(long flags);
    void curl_global_cleanup(void);

    /* callbacks */
    typedef size_t (*curl_write_callback)(char *buffer, size_t size, size_t nitems, void *outstream);

    /* easy.h */
    CURL *curl_easy_init(void);
    CURLcode curl_easy_setopt(CURL *curl, CURLoption option, ...);
    CURLcode curl_easy_perform(CURL *curl);
    void curl_easy_cleanup(CURL *curl);

    CURLcode curl_easy_getinfo(CURL *curl, CURLINFO info, ... );
  ]]

  local run_wrapper = function(fn, ...)
    print(clib.curl_global_init(3)) -- check if true
    local result = fn(ffi, clib, ...)
    clib.curl_global_cleanup()
    return result
  end

  return {
    get = function(...) return run_wrapper(get_func, ...) end

  }
end

return (function()
  local ok, m = pcall(native_init)
  if not ok then return {} end
  return m
end)()
