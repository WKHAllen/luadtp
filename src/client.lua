local util = require("luadtp.util")

local Client = {}
Client.__index = Client

function Client.new()
  -- TODO: construct and return client table
end

function Client:connect()
  -- TODO: connect to server
end

-- TODO: other client methods

return {
  Client = Client,
}
