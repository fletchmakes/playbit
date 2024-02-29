local module = {}
playdate.datastore = module

local jsonParser = require("json.json")

function module.write(table, filename, prettyPrint)
  filename = filename or "data"
  filename = filename..".json"
  prettyPrint = prettyPrint or false
  -- TODO: json lib doesn't support pretty printing
  @@ASSERT(not prettyPrint, "Print print parameter is not implemented.")
  local str = jsonParser.encode(table)
  love.filesystem.write(filename, str)
end

function module.read(filename)
  filename = filename or "data"
  filename = filename..".json"

  local str, size = love.filesystem.read(filename)
  local table = jsonParser.decode(str)
  return table
end

function module.delete(filename)
  filename = filename or "data"
  filename = filename..".json"
  love.filesystem.remove(filename)
end