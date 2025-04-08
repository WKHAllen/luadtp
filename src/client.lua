local util = require("luadtp.util")
local crypto = require("luadtp.crypto")
local socket = require("socket")

local Client = {}
Client.__index = Client

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

function Client.new()
  local client = setmetatable({
    _isConnected = false,
    _sock = nil,
    _key = nil,
  }, Client)

  return client
end

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

function Client:disconnect()
  if not self._isConnected then
    error("client is not connected to a server")
  end

  self._isConnected = false
  self._sock:close()
end

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

function Client:connected()
  return self._isConnected
end

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
