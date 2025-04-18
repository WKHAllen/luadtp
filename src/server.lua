---@module "src.util"
local util = require("luadtp.util")
---@module "src.crypto"
local crypto = require("luadtp.crypto")
local socket = require("socket")

---@class ServerInner
---@field accept function
---@field close function
---@field settimeout function
---@field getsockname function

---@class Server
---@field _isServing boolean Whether the server is serving.
---@field _sock ServerInner The underlying server socket.
---@field _clients { [integer]: { conn: ClientInner, key: string } } The list of connected clients.
---@field _nextClientId integer The next available client identifier.
local Server = {}
Server.__index = Server

---Performs a cryptographic key exchange with a connecting client.
---@param server Server The network server.
---@param clientId integer The client's identifier.
---@param conn ClientInner The underlying connection to the client socket.
local function exchangeKeys(server, clientId, conn)
  local publicKey, privateKey = crypto.newRsaKeyPair()
  local publicKeySize = util.encodeMessageSize(#publicKey)
  local publicKeyBuffer = publicKeySize .. publicKey
  local n, err = conn:send(publicKeyBuffer)
  if err ~= nil then
    error("server socket key exchange error: " .. err)
  end

  if n ~= #publicKeyBuffer then
    error("server socket did not send all bytes during key exchange (" .. n .. "/" .. #publicKeyBuffer .. ")")
  end

  local size, err = conn:receive(util.lenSize)
  if err ~= nil then
    error("server key exchange error: " .. err)
  end

  local keySize = util.decodeMessageSize(size)
  local encryptedKey, err = conn:receive(keySize)
  if err ~= nil then
    error("server key exchange error: " .. err)
  end

  local key = crypto.rsaDecrypt(privateKey, encryptedKey)
  server._clients[clientId] = {
    conn = conn,
    key = key,
  }
end

---Returns the next available client ID.
---@param server Server The network server.
---@return integer # The next available client ID.
local function newClientId(server)
  local clientId = server._nextClientId
  server._nextClientId = server._nextClientId + 1
  return clientId
end

---Performs a single polling and event-triggering cycle for a given client.
---@param server Server The network server.
---@param clientId integer The client's ID.
local function serveClient(server, clientId)
  local client = server._clients[clientId]
  local size, err = client.conn:receive(util.lenSize)
  if err == nil then
    local msgSize = util.decodeMessageSize(size)
    local buffer, err = client.conn:receive(msgSize)
    if err == nil then
      local bufferDecrypted = crypto.aesDecrypt(client.key, buffer)
      local data = util.deserialize(bufferDecrypted)
      coroutine.yield({ eventType = "receive", clientId = clientId, data = data })
    else
      client.conn:close()
      server._clients[clientId] = nil
      coroutine.yield({ eventType = "disconnect", clientId = clientId })
    end
  elseif err ~= "timeout" then
    client.conn:close()
    server._clients[clientId] = nil
    coroutine.yield({ eventType = "disconnect", clientId = clientId })
  end
end

---Performs a single polling and event-triggering cycle for the server.
---@param server Server The network server.
local function serve(server)
  while server._isServing do
    local conn, err = server._sock:accept()
    if err == nil then
      local clientId = newClientId(server)
      exchangeKeys(server, clientId, conn)
      conn:settimeout(0)
      coroutine.yield({ eventType = "connect", clientId = clientId })
    elseif err ~= "timeout" then
      break
    end

    for clientId, _ in pairs(server._clients) do
      serveClient(server, clientId)
    end

    coroutine.yield()
  end
end

---Constructs and returns a new network server.
---@return Server
function Server.new()
  local server = setmetatable({
    _isServing = false,
    _sock = nil,
    _clients = {},
    _nextClientId = 1,
  }, Server)

  return server
end

---Starts the server listening on a given host and port.
---@param host string The host address.
---@param port integer The port.
---@return thread # A coroutine that must be polled to handle server events. Note that if this is not polled, clients will not be able to connect.
function Server:start(host, port)
  if self._isServing then
    error("server is already serving")
  end

  local sock, err = socket.bind(host, port)
  if err ~= nil then
    error("server socket bind error: " .. err)
  end

  sock:setoption("reuseaddr", true)
  self._sock = sock
  self._isServing = true
  self._sock:settimeout(0)

  local co = coroutine.create(function ()
    serve(self)
  end)

  return co
end

---Stops the server, disconnecting all clients in the process.
function Server:stop()
  if not self._isServing then
    error("server is not serving")
  end

  self._isServing = false

  for _, client in pairs(self._clients) do
    client.conn:close()
  end

  self._sock:close()
end

---Sends data to a set of clients.
---@param data any The data to send.
---@param clientId integer The ID of the client to send the data to.
---@param ... integer Additional IDs of clients to send the data to.
function Server:send(data, clientId, ...)
  local clientIds = {...}
  table.insert(clientIds, 1, clientId)
  local dataSerialized = util.serialize(data)

  for _, clientId in ipairs(clientIds) do
    local client = self._clients[clientId]
    local dataEncrypted = crypto.aesEncrypt(client.key, dataSerialized)
    local size = util.encodeMessageSize(#dataEncrypted)
    local buffer = size .. dataEncrypted
    local n, err = client.conn:send(buffer)
    if err ~= nil then
      error("server socket send error: " .. err)
    end

    if n ~= #buffer then
      error("server socket did not send all bytes (" .. n .. "/" .. #buffer .. ")")
    end
  end
end

---Sends data to all connected clients.
---@param data any The data to send.
function Server:sendAll(data)
  local clientIds = {}

  for clientId, _ in ipairs(self._clients) do
    table.insert(clientIds, clientId)
  end

  self:send(data, table.unpack(clientIds))
end

---Is the server currently serving?
---@return boolean
function Server:serving()
  return self._isServing
end

---Returns the server's address.
---@return string # The server's host address.
---@return integer # The server's port.
function Server:getAddr()
  if not self._isServing then
    error("server is not serving")
  end

  local host, port, _ = self._sock:getsockname()
  if host == nil then
    error("server socket failed to get local address")
  end

  return host, port
end

---Returns a client's address.
---@param clientId integer The client's ID.
---@return string # The client's host address.
---@return integer # The client's port.
function Server:getClientAddr(clientId)
  if not self._isServing then
    error("server is not serving")
  end

  local host, port, _ = self._clients[clientId].conn:getpeername()
  if host == nil then
    error("server socket failed to get remote client address")
  end

  return host, port
end

---Disconnects a client from the server.
---@param clientId integer # The client's ID.
function Server:removeClient(clientId)
  if not self._isServing then
    error("server is not serving")
  end

  self._clients[clientId].conn:close()
  self._clients[clientId] = nil
end

return {
  Server = Server,
}
