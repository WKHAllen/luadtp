---@module "src.client"
local clientImpl = require("luadtp.client")
---@module "src.server"
local serverImpl = require("luadtp.server")

---Constructs and returns a new network client.
---@return Client
local function client()
  return clientImpl.Client:new()
end

---Constructs and returns a new network server.
---@return Server
local function server()
  return serverImpl.Server:new()
end

return {
  client = client,
  server = server,
}
