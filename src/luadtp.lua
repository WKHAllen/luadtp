local clientImpl = require("luadtp.client")
local serverImpl = require("luadtp.server")

local function client()
  return clientImpl.Client:new()
end

local function server()
  return serverImpl.Server:new()
end

return {
  client = client,
  server = server,
}
