local crypto = require("luadtp.cryptocore")

local lenSize = 5

local function encodeMessageSize(size)
  return crypto.encode_message_size(size)
end

local function decodeMessageSize(encodedSize)
  return crypto.decode_message_size(encodedSize)
end

return {
  lenSize = lenSize,
  encodeMessageSize = encodeMessageSize,
  decodeMessageSize = decodeMessageSize,
}
