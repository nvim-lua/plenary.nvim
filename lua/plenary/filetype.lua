local path = require('plenary.path').path

local os_sep = path.sep

local filetype = {}

local filetype_table = {
  extension = {},
  file_name = {},
}

filetype.add_table = function(new_filetypes)
  local valid_keys = {'extension', 'file_name'}
  local new_keys = {}
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
end

filetype.add_file = function(filename)
  local filetype_files = vim.api.nvim_get_runtime_file(
    string.format(
      "data/plenary/filetypes/%s.lua", filename
    ), true
  )

  for _, file in ipairs(filetype_files) do
    local ok, msg = pcall(filetype.add_table, dofile(file))
    if not ok then
      error("Unable to add file " .. file .. ":\n" .. msg)
    end
  end
end

filetype._get_extension = function(filename)
  local ext_with_period = filename:match("^.+(%..+)$")
  if ext_with_period then
    return ext_with_period:sub(2)
  end
end


filetype.detect = function(filepath)
  filepath = filepath:lower()

  local ext = filetype._get_extension(filepath)
  local match = ext and filetype_table.extension[ext]
  if match then return match end

  local split_path = vim.split(filepath, os_sep, true)
  local fname = split_path[#split_path]
  match = filetype_table.file_name[fname]
  if match then return match end

  return ''
end


filetype.add_file("base")
filetype.add_file("builtin")

return filetype
