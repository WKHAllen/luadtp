local util = require("luadtp.util")
local crypto = require("luadtp.crypto")
local socket = require("socket")

local Server = {}
Server.__index = Server

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

local function newClientId(server)
  local clientId = server._nextClientId
  server._nextClientId = server._nextClientId + 1
  return clientId
end

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

function Server.new()
  local server = setmetatable({
    _isServing = false,
    _sock = nil,
    _clients = {},
    _nextClientId = 0,
  }, Server)

  return server
end

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

function Server:send(data, clientId, ...)
  local clientIds = arg
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

function Server:sendAll(data)
  local clientIds = {}

  for _, clientId in ipairs(self._clients) do
    table.insert(clientIds, clientId)
  end

  self:send(data, table.unpack(clientIds))
end

function Server:serving()
  return self._isServing
end

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
