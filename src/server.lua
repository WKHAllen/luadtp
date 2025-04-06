local util = require("luadtp.util")

local Server = {}
Server.__index = Server

function Server.new()
  -- TODO: construct and return server table
end

function Server:start()
  -- TODO: start the server
end

-- TODO: other server methods

return {
  Server = Server,
}
