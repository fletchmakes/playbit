-- this build script was only designed to run on Windows!
local folderOfThisFile = (...):match("(.-)[^%.]+$")
local pp = require(folderOfThisFile.."LuaPreprocess.preprocess")
local capToBmfont = require(folderOfThisFile.."tools.caps-to-bmfont")

local module = {}

function module.listFiles(folder)
  local dirCommand = io.popen("dir /a-D /S /B \""..folder.."\"")
  local output = dirCommand:read("*a")
  return output:gmatch("(.-)\n")
end

function module.getFileExtension(path)
  return path:match("^.+%.(.+)$")
end

function module.createFolderIfNeeded(path)
  local pathReversed = string.reverse(path)
  local start, ends = string.find(pathReversed, "\\")
  local trimmedPath = string.sub(path, 1, #path - ends)
  os.execute("IF NOT EXIST "..trimmedPath.." mkdir "..trimmedPath)
end

function module.getAbsolutePath(path)
  local dirCommand = io.popen("cd")
  return dirCommand:read("*l").."\\"..path
end

function module.getRelativePath(path, folder)
  path = path:gsub(folder, "")
  local char = string.sub(path, 1, 1)
  if (char == "\\") then
    -- trim leading slash
    path = string.sub(path, 2)
  end
  return path
end

-- TODO: need to add this as file processor - does aseprite support returning the file?
-- function module.exportAseprite(inputFolder, outputFolder, ignoredLayers, verbose)
--   local dirCommand = io.popen("dir /a-D /S /B \"" .. inputFolder .. "\"")
--   local dirOutput = dirCommand:read("*a")

--   dirCommand = io.popen("cd")
--   local fullInputFolder = dirCommand:read("*l").."\\"..inputFolder
  
--   for fullPath in dirOutput:gmatch("(.-)\n") do 
--     if module.getFileExtension(fullPath) ~= ".aseprite" then
--       goto continue
--     end

--     local relativeOutputPath = fullPath:gsub(fullInputFolder, ""):gsub(".aseprite", ".png")
--     relativeOutputPath = outputFolder .. relativeOutputPath

--     -- create folder(s) first to fix errors when writing lua fila
--     module.createFolderIfNeeded(relativeOutputPath:match("(.*\\)"))

--     -- TODO: expose param to set aseprite location
--     local command = "\"C:\\Program Files\\Aseprite\\Aseprite.exe\" -bv "
--     command = command..fullPath
--     for i = 1, #ignoredLayers, 1 do
--       command = command.." --ignore-layer "..ignoredLayers[i]
--     end
--     command = command.." --save-as "..relativeOutputPath
--     io.popen(command, "w")

--     ::continue::
--   end
-- end

function module.processFnt(fileContents)
  capToBmfont()
end

function module.processLua(fileContents)
  -- remove comments so preprocess can...process them
  -- TODO: this is probably slow...is there a better way to handle this?
  fileContents = fileContents:gsub("--!", "!")

  -- run preprocess magic
  local processedLua, processedFileInfo = pp.processString {
    code = fileContents,
  }

  if verbose then
    print("Processed " .. fullPath .. " " .. processedFileInfo.processedByteCount .. " bytes")
  end

  return processedLua
end

function module.getProjectFolder()
  local cdCommand = io.popen("cd")
  return cdCommand:read("*l")
end

function module.getFiles(path)
  local dirCommand = io.popen("dir /a-d /s /b \""..path.."\"")
  local files = dirCommand:read("*a"):gmatch("(.-)\n")
  local result = {}
  for path in files do 
    table.insert(result, path)
  end
  return result
end

function module.processFile(input, output, fileProcessors)
  local ext = module.getFileExtension(input)
  local processor = fileProcessors[ext]

  -- if there is a file processor, we want the mode to be in plain text
  -- other wise mode needs to be binary to copy files like images correctly
  local writeMode = "w+b"
  local readMode = "rb"
  if processor then
    writeMode = "w+"
    readMode = "r"
  end

  local inputFile = io.open(input, readMode)
  local contents = inputFile:read("a")
  inputFile:close()
  
  if processor then
    contents = processor(contents)
  end

  module.createFolderIfNeeded(output)
  local outputFile = io.open(output, writeMode)
  outputFile:write(contents)
  outputFile:close();
end

function module.processPath(projectFolder, buildFolder, inputPath, outputPath, fileProcessors)
  local files = module.getFiles(inputPath)
  if #files == 1 then
    -- process single file
    local filePath = files[1]
    local outputFilePath = projectFolder.."\\"..buildFolder.."\\"..outputPath
    module.processFile(filePath, outputFilePath, fileProcessors)
  else
    -- process files in folder recursively
    local fullInputPath = projectFolder.."\\"..inputPath
    for i = 1, #files, 1 do
      local filePath = files[i]
      local relativeFilePath = module.getRelativePath(filePath, fullInputPath)
      local outputFilePath = projectFolder.."\\"..buildFolder.."\\"..outputPath.."\\"..relativeFilePath
      module.processFile(filePath, outputFilePath, fileProcessors)
    end
  end
end

function module.build(options)
  local timeStart = os.clock()

  local enableVerbose = options.verbose == true
  local targetPlatform = options.platform
  local projectFolder = module.getProjectFolder()
  local processors = options.fileProcessors

  -- built in env values
  pp.metaEnvironment.PLAYDATE = targetPlatform == "playdate"
  pp.metaEnvironment.LOVE2D = targetPlatform == "love2d"
  pp.metaEnvironment.ASSERT = options.assert
  pp.metaEnvironment.DEBUG = options.debug

  -- any game specific env values
  if options.env then
    for i = 1, #options.env, 1 do
      pp.metaEnvironment[options.env[i]] = true
    end
  end

  local buildFolder = "_game"
  if options.output then
    buildFolder = options.output
  end

  -- nuke old folder
  os.execute("rmdir "..buildFolder.." /s /q")
  os.execute("mkdir "..buildFolder)

  for i = 1, #options.folders, 1 do
    module.processPath(projectFolder, buildFolder, options.folders[i][1], options.folders[i][2], processors)
  end

  local timeEnd = os.clock()
  print("Build completed in "..(timeEnd - timeStart).."ms")
end

return module