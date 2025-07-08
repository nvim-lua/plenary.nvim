--qqq

-- utils.lua
local M = {}

M.is_msys2 = (function()
  -- Run this once
  local ok, result = pcall(vim.fn.system, "uname")
  if ok and result then
    if result:match("MINGW64_NT") or
        result:match("MINGW32_NT") or
        result:match("MSYS_NT") then
      return true
    end
  end
  return false
end)()

-- How can we find msys2 installation
-- if it cannot be located from ENV vars?
-- Registry?
-- Or using vim.fn.expand("~") which expands to Windows style path?
M.msys2_root = M.is_msys2 and (function()
  -- msys2 path in windows style
  -- C:\\msys64 is a common location
  return vim.fn.expand("~"):match("^.*msys64")
end)() or nil

M.msys2_root_map = M.msys2_root and (function()
  -- Direct root mapping
  return {
    ["/bin"] = M.msys2_root .. "\\bin",
    ["/clang64"] = M.msys2_root .. "\\clang64",
    ["/clangarm64"] = M.msys2_root .. "\\clangarm64",
    ["/dev"] = M.msys2_root .. "\\dev",
    ["/etc"] = M.msys2_root .. "\\etc",
    ["/home"] = M.msys2_root .. "\\home",
    ["/installerResources"] = M.msys2_root .. "\\installerResources",
    ["/mingw32"] = M.msys2_root .. "\\mingw32",
    ["/mingw64"] = M.msys2_root .. "\\mingw64",
    ["/opt"] = M.msys2_root .. "\\opt",
    ["/proc"] = M.msys2_root .. "\\proc",
    ["/tmp"] = M.msys2_root .. "\\tmp",
    ["/ucrt64"] = M.msys2_root .. "\\ucrt64",
    ["/usr"] = M.msys2_root .. "\\usr",
    ["/var"] = M.msys2_root .. "\\var"
  }
end)() or nil

-- msys2 to windows actually.
function M.posix_to_windows(posix_path)
  -- Sanity checks
  if not posix_path or not M.msys2_root or not #M.msys2_root then
    return posix_path
  end


  local prefix_changed = false


  -- For edgy-ephemeral cases when vim.fn.expand() eats posix-style path.
  -- In that case we get forward slashes everywhere which we don't need
  -- when working with libuv which uses WinAPI under the hood.
  -- E.g. vim.fn.expand("/home/User") gives "\home\User".
  posix_path = posix_path:gsub("\\", "/")


  -- Another one edgy-ephemeral case when we have only "/".
  if not prefix_changed and #posix_path == 1 and posix_path:find("/") then
    --vim.notify("Only '/' case: " .. posix_path, vim.log.levels.WARN)
    ---@type string
    posix_path = M.msys2_root
    prefix_changed = true
  end


  -- Apply root folder mappings only if path starts with "/" and has at least 3 chars after
  if not prefix_changed and posix_path:find("^/[A-Za-z][A-Za-z][A-Za-z]") then
    for prefix, replacement in pairs(M.msys2_root_map) do
      if posix_path:find("^" .. prefix) then
        --vim.notify("msys2 root mapping case: " .. posix_path, vim.log.levels.WARN)
        posix_path = posix_path:gsub("^" .. prefix, replacement)
        prefix_changed = true
        break
      end
    end
  end


  -- Drive letter paths /c/Users -> C:\\Users (+edge case on fast pane split in WezTerm /C:/Users -> C:\\Users).
  -- It is possible to have only "/c" (w/o trailing "/") but not "/C:" (WezTerm internally trails it with "/").
  -- Idk if WezTerm paths behaviour leaks to msys2 actually...
  if not prefix_changed then
    if #posix_path == 2 and posix_path:find("/[A-Za-z]") then
      --vim.notify("Only '[A-Za-z]:' case: " .. posix_path, vim.log.levels.WARN)
      posix_path = posix_path:gsub("^/([A-Za-z])", "%1:\\")
      prefix_changed = true
    else
      --vim.notify("'[A-Za-z]:?/' case: " .. posix_path, vim.log.levels.WARN)
      posix_path = posix_path:gsub("^/([A-Za-z]):?/", "%1:\\")
      prefix_changed = true
    end
  end

  -- Lets try to be msys2 compliant for testing.
  --posix_path = posix_path:gsub("^/([A-Za-z]):?([^0-9A-Za-z_-]?)", "/%1%2")


  -- Replace remaining forward slashes with backslashes.
  posix_path = posix_path:gsub("/", "\\")

  -- For bash.exe (nvim shell) it is better to use backslashes
  -- cause forward slashes must be escaped. Need to come up with something
  -- cause nvim for windows (even clang64 binary) prefers windows-style paths (with backslashes?).
  --posix_path = posix_path:gsub("\\", "/")


  -- Drive letter to upper case
  if posix_path:find("^[a-z]:") then
    posix_path = posix_path:sub(1, 1):upper() .. posix_path:sub(2)
  end


  return posix_path
end

return M
--!qqq
