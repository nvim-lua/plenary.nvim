local Path = require "plenary.path"

local os_sep = Path.path.sep

local filetype = {}

local filetype_table = {
  extension = {},
  file_name = {},
  shebang = {},
}

filetype.add_table = function(new_filetypes)
  local valid_keys = { "extension", "file_name", "shebang" }
  local new_keys = {}

  -- Validate keys
  for k, _ in pairs(new_filetypes) do
    new_keys[k] = true
  end
  for _, k in ipairs(valid_keys) do
    new_keys[k] = nil
  end

  for k, v in pairs(new_keys) do
    error(debug.traceback("Invalid key / value:" .. tostring(k) .. " / " .. tostring(v)))
  end

  if new_filetypes.extension then
    filetype_table.extension = vim.tbl_extend("force", filetype_table.extension, new_filetypes.extension)
  end

  if new_filetypes.file_name then
    filetype_table.file_name = vim.tbl_extend("force", filetype_table.file_name, new_filetypes.file_name)
  end

  if new_filetypes.shebang then
    filetype_table.shebang = vim.tbl_extend("force", filetype_table.shebang, new_filetypes.shebang)
  end
end

filetype.add_file = function(filename)
  local filetype_files = vim.api.nvim_get_runtime_file(string.format("data/plenary/filetypes/%s.lua", filename), true)

  for _, file in ipairs(filetype_files) do
    local ok, msg = pcall(filetype.add_table, dofile(file))
    if not ok then
      error("Unable to add file " .. file .. ":\n" .. msg)
    end
  end
end

local filename_regex = "[^" .. os_sep .. "].*"
filetype._get_extension_parts = function(filename)
  local current_match = filename:match(filename_regex)
  local possibilities = {}
  while current_match do
    current_match = current_match:match "[^.]%.(.*)"
    if current_match then
      table.insert(possibilities, current_match:lower())
    else
      return possibilities
    end
  end
  return possibilities
end

filetype._parse_modeline = function(tail)
  if tail:find "vim:" then
    return tail:match ".*:ft=([^: ]*):.*$" or ""
  end
  return ""
end

filetype._parse_shebang = function(head)
  if head:sub(1, 2) == "#!" then
    local match = filetype_table.shebang[head:sub(3, #head)]
    if match then
      return match
    end
  end
  return ""
end

local done_adding = false
local extend_tbl_with_ext_eq_ft_entries = function()
  if not done_adding then
    if vim.in_fast_event() then
      return
    end
    local all_valid_filetypes = vim.fn.getcompletion("", "filetype")
    for _, v in ipairs(all_valid_filetypes) do
      if not filetype_table.extension[v] then
        filetype_table.extension[v] = v
      end
    end
    done_adding = true
    return true
  end
end

filetype.detect_from_extension = function(filepath)
  local exts = filetype._get_extension_parts(filepath)
  for _, ext in ipairs(exts) do
    local match = ext and filetype_table.extension[ext]
    if match then
      return match
    end
  end
  if extend_tbl_with_ext_eq_ft_entries() then
    for _, ext in ipairs(exts) do
      local match = ext and filetype_table.extension[ext]
      if match then
        return match
      end
    end
  end
  return ""
end

filetype.detect_from_name = function(filepath)
  filepath = filepath:lower()
  local split_path = vim.split(filepath, os_sep, true)
  local fname = split_path[#split_path]
  local match = filetype_table.file_name[fname]
  if match then
    return match
  end
  return ""
end

filetype.detect_from_modeline = function(filepath)
  if not filepath then
    local tail = vim.api.nvim_buf_get_lines(0, -2, -1, false)
    if #tail == 0 then
      return ""
    end
    tail = tail[1]
    return filetype._parse_modeline(tail)
  else
    local tail = Path:new(filepath):readbyterange(-256, 256)
    if not tail then
      return ""
    end
    local lines = vim.split(tail, "\n")
    local idx = lines[#lines] ~= "" and #lines or #lines - 1
    if idx >= 1 then
      return filetype._parse_modeline(lines[idx])
    end
  end
end

filetype.detect_from_shebang = function(filepath)
  local head = ""
  if not filepath then
    head = vim.api.nvim_buf_get_lines(0, 0, 1, false)
    if #head == 0 then
      return ""
    end
    head = head[1]
  else
    local _head = Path:new(filepath):readbyterange(0, 256)
    if not head then
      return ""
    end
    head = vim.split(head, "\n")[1]
  end
  return filetype._parse_shebang(head)
end

--- Detect a filetype from a path or buffer.
---
---@param filepath: Optional string of filename
---@param opts table: Table with optional keys
---     - fs_access (bool, default=true): Should check a file if it exists
filetype.detect = function(filepath, opts)
  opts = opts or {}
  opts.fs_access = opts.fs_access or true

  if filepath then
    local match = filetype.detect_from_name(filepath)
    if match ~= "" then
      return match
    end

    match = filetype.detect_from_extension(filepath)
  end
  if not filepath or (opts.fs_access and Path:new(filepath):exists()) then
    if match == "" or not filepath then
      match = filetype.detect_from_shebang(filepath)
      if match ~= "" then
        return match
      end
    end

    if match == "text" or match == "" then
      match = filetype.detect_from_modeline(filepath)
      if match ~= "" then
        return match
      end
    end
  end

  return match
end

filetype.add_file "base"
filetype.add_file "builtin"

return filetype
