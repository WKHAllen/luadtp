---@module "src.util"
local util = require("luadtp.util")
---@module "src.crypto"
local crypto = require("luadtp.crypto")
local socket = require("socket")

---@class ClientInner
---@field send function
---@field receive function
---@field close function
---@field settimeout function
---@field getsockname function
---@field getpeername function

---@class Client
---@field _isConnected boolean Whether the client is connected to a server.
---@field _sock ClientInner The underlying client socket.
---@field _key string The AES encryption key.
local Client = {}
Client.__index = Client

---Performs a cryptographic key exchange with the server.
---@param client Client The network client.
local function exchangeKeys(client)
  local size, err = client._sock:receive(util.lenSize)
  if err ~= nil then
    error("client key exchange error: " .. err)
  end

  local publicKeySize = util.decodeMessageSize(size)
  local publicKey, err = client._sock:receive(publicKeySize)
  if err ~= nil then
    error("client key exchange error: " .. err)
  end

  local key = crypto.newAesKey()
  local encryptedKey = crypto.rsaEncrypt(publicKey, key)
  local encryptedKeySize = util.encodeMessageSize(#encryptedKey)
  local encryptedKeyBuffer = encryptedKeySize .. encryptedKey
  local n, err = client._sock:send(encryptedKeyBuffer)
  if err ~= nil then
    error("client socket key exchange send error: " .. err)
  end

  if n ~= #encryptedKeyBuffer then
    error("client socket did not send all bytes during key exchange (" .. n .. "/" .. #encryptedKeyBuffer .. ")")
  end

  client._key = key
end

---Performs a single polling and event-triggering cycle.
---@param client Client The network client.
local function handle(client)
  while client._isConnected do
    local size, err = client._sock:receive(util.lenSize)
    if err == nil then
      local msgSize = util.decodeMessageSize(size)
      local buffer, err = client._sock:receive(msgSize)
      if err ~= nil then
        break
      end

      local bufferDecrypted = crypto.aesDecrypt(client._key, buffer)
      local data = util.deserialize(bufferDecrypted)
      coroutine.yield({ eventType = "receive", data = data })
    elseif err ~= "timeout" then
      break
    end

    coroutine.yield()
  end

  if client._isConnected then
    client._isConnected = false
    client._sock:close()
    coroutine.yield({ eventType = "disconnected" })
  end
end

---Constructs and returns a new network client.
---@return Client
function Client.new()
  local client = setmetatable({
    _isConnected = false,
    _sock = nil,
    _key = nil,
  }, Client)

  return client
end

---Connects to a server.
---@param host string The server host address.
---@param port integer The server port.
---@return thread # A coroutine that must be polled to handle client events.
function Client:connect(host, port)
  if self._isConnected then
    error("client is already connected to a server")
  end

  local sock, err = socket.connect(host, port)
  if err ~= nil then
    error("client socket connect error: " .. err)
  end

  sock:setoption("reuseaddr", true)
  self._sock = sock
  self._isConnected = true
  exchangeKeys(self)
  self._sock:settimeout(0)

  local co = coroutine.create(function ()
    handle(self)
  end)

  return co
end

---Disconnects from the server.
function Client:disconnect()
  if not self._isConnected then
    error("client is not connected to a server")
  end

  self._isConnected = false
  self._sock:close()
end

---Sends data to the server.
---@param data any The data to send.
function Client:send(data)
  if not self._isConnected then
    error("client is not connected to a server")
  end

  local dataSerialized = util.serialize(data)
  local dataEncrypted = crypto.aesEncrypt(self._key, dataSerialized)
  local size = util.encodeMessageSize(#dataEncrypted)
  local buffer = size .. dataEncrypted
  local n, err = self._sock:send(buffer)
  if err ~= nil then
    error("client socket send error: " .. err)
  end

  if n ~= #buffer then
    error("client socket did not send all bytes (" .. n .. "/" .. #buffer .. ")")
  end
end

---Is the client currently connected to a server?
---@return boolean
function Client:connected()
  return self._isConnected
end

---Returns the client's address.
---@return string # The client's host address.
---@return integer # The client's port.
function Client:getAddr()
  if not self._isConnected then
    error("client is not connected to a server")
  end

  local host, port, _ = self._sock:getsockname()
  if host == nil then
    error("client socket failed to get local address")
  end

  return host, port
end

---Returns the server's address.
---@return string # The server's host address.
---@return integer # The server's port.
function Client:getServerAddr()
  if not self._isConnected then
    error("client is not connected to a server")
  end

  local host, port, _ = self._sock:getpeername()
  if host == nil then
    error("client socket failed to get remote address")
  end

  return host, port
end

return {
  Client = Client,
}
