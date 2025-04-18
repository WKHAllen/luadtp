local crypto = require("luadtp.cryptocore")
local binser = require("binser")

local lenSize = 5

---Encodes the size portion of a message.
---@param size integer The size of the message.
---@return string # The encoded size.
local function encodeMessageSize(size)
  return crypto.encode_message_size(size)
end

---Decodes the size portion of a message.
---@param encodedSize string The encoded message size.
---@return integer # The decoded size.
local function decodeMessageSize(encodedSize)
  return crypto.decode_message_size(encodedSize)
end

---Serializes a piece of data.
---@param data any
---@return string # The serialized data.
local function serialize(data)
  return binser.serialize(data)
end

---Deserializes a serialized piece of data.
---@param serializedData string
---@return any # The deserialized data.
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
