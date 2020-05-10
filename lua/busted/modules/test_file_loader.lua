local s = require 'say'

return function(busted, loaders)
  local path = require 'pl.path'
  local dir = require 'pl.dir'
  local tablex = require 'pl.tablex'
  local fileLoaders = {}

  for _, v in pairs(loaders) do
    local loader = require('busted.modules.files.'..v)
    fileLoaders[#fileLoaders+1] = loader
  end

  local getTestFiles = function(rootFile, patterns, options)
    local fileList

    if path.isfile(rootFile) then
      fileList = { rootFile }
    elseif path.isdir(rootFile) then
      local getfiles = options.recursive and dir.getallfiles or dir.getfiles
      fileList = getfiles(rootFile)

      fileList = tablex.filter(fileList, function(filename)
        local basename = path.basename(filename)
        for _, patt in ipairs(options.excludes) do
          if patt ~= '' and basename:find(patt) then
            return nil
          end
        end
        for _, patt in ipairs(patterns) do
          if basename:find(patt) then
            return true
          end
        end
        return #patterns == 0
      end)

      fileList = tablex.filter(fileList, function(filename)
        if path.is_windows then
          return not filename:find('%\\%.%w+.%w+', #rootFile)
        else
          return not filename:find('/%.%w+.%w+', #rootFile)
        end
      end)
    else
      busted.publish({ 'error' }, {}, nil, s('output.file_not_found'):format(rootFile), {})
      fileList = {}
    end

    table.sort(fileList)
    return fileList
  end

  local getAllTestFiles = function(rootFiles, patterns, options)
    local fileList = {}
    for _, root in ipairs(rootFiles) do
      tablex.insertvalues(fileList, getTestFiles(root, patterns, options))
    end
    return fileList
  end

  -- runs a testfile, loading its tests
  local loadTestFile = function(busted, filename)
    for _, v in pairs(fileLoaders) do
      if v.match(busted, filename) then
        return v.load(busted, filename)
      end
    end
  end

  local loadTestFiles = function(rootFiles, patterns, options)
    local fileList = getAllTestFiles(rootFiles, patterns, options)

    for i, fileName in ipairs(fileList) do
      local testFile, getTrace, rewriteMessage = loadTestFile(busted, fileName)

      if testFile then
        local file = setmetatable({
          getTrace = getTrace,
          rewriteMessage = rewriteMessage
        }, {
          __call = testFile
        })

        busted.executors.file(fileName, file)
      end
    end

    if #fileList == 0 then
      local pattern = patterns[1]
      if #patterns > 1 then
        pattern = '\n\t' .. table.concat(patterns, '\n\t')
      end
      busted.publish({ 'error' }, {}, nil, s('output.no_test_files_match'):format(pattern), {})
    end

    return fileList
  end

  return loadTestFiles, loadTestFile, getAllTestFiles
end

