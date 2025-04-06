local crypto = require("luadtp.cryptocore")
local binser = require("binser")

local lenSize = 5

local function encodeMessageSize(size)
  return crypto.encode_message_size(size)
end

local function decodeMessageSize(encodedSize)
  return crypto.decode_message_size(encodedSize)
end

local function serialize(data)
  return binser.serialize(data)
end

local function deserialize(serializedData)
  local results, _ = binser.deserialize(serializedData)
  return results[1]
end

return {
  lenSize = lenSize,
  encodeMessageSize = encodeMessageSize,
  decodeMessageSize = decodeMessageSize,
  serialize = serialize,
  deserialize = deserialize
}
