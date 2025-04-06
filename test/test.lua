local luadtp = require("luadtp")
local crypto = require("luadtp.crypto")
local util = require("luadtp.util")

local function testEncodeMessageSize()
  assert(util.encodeMessageSize(0) == string.char(0, 0, 0, 0, 0))
  assert(util.encodeMessageSize(1) == string.char(0, 0, 0, 0, 1))
  assert(util.encodeMessageSize(255) == string.char(0, 0, 0, 0, 255))
  assert(util.encodeMessageSize(256) == string.char(0, 0, 0, 1, 0))
  assert(util.encodeMessageSize(257) == string.char(0, 0, 0, 1, 1))
  assert(util.encodeMessageSize(4311810305) == string.char(1, 1, 1, 1, 1))
  assert(util.encodeMessageSize(4328719365) == string.char(1, 2, 3, 4, 5))
  assert(util.encodeMessageSize(47362409218) == string.char(11, 7, 5, 3, 2))
  assert(util.encodeMessageSize(1099511627775) == string.char(255, 255, 255, 255, 255))
end

local function testDecodeMessageSize()
  assert(util.decodeMessageSize(string.char(0, 0, 0, 0, 0)) == 0)
  assert(util.decodeMessageSize(string.char(0, 0, 0, 0, 1)) == 1)
  assert(util.decodeMessageSize(string.char(0, 0, 0, 0, 255)) == 255)
  assert(util.decodeMessageSize(string.char(0, 0, 0, 1, 0)) == 256)
  assert(util.decodeMessageSize(string.char(0, 0, 0, 1, 1)) == 257)
  assert(util.decodeMessageSize(string.char(1, 1, 1, 1, 1)) == 4311810305)
  assert(util.decodeMessageSize(string.char(1, 2, 3, 4, 5)) == 4328719365)
  assert(util.decodeMessageSize(string.char(11, 7, 5, 3, 2)) == 47362409218)
  assert(util.decodeMessageSize(string.char(255, 255, 255, 255, 255)) == 1099511627775)
end

local function testCrypto()
  local rsaMessage = "Hello, RSA!"
  local publicKey, privateKey = crypto.newRsaKeyPair()
  local rsaEncrypted = crypto.rsaEncrypt(publicKey, rsaMessage)
  local rsaDecrypted = crypto.rsaDecrypt(privateKey, rsaEncrypted)
  print("Original string:  '" .. rsaMessage .. "'")
  print("Encrypted string: '" .. rsaEncrypted .. "'")
  print("Decrypted string: '" .. rsaDecrypted .. "'")
  assert(rsaDecrypted == rsaMessage)
  assert(rsaEncrypted ~= rsaMessage)

  local aesMessage = "Hello, AES!"
  local key = crypto.newAesKey()
  local aesEncrypted = crypto.aesEncrypt(key, aesMessage)
  local aesDecrypted = crypto.aesDecrypt(key, aesEncrypted)
  print("Original string:  '" .. aesMessage .. "'")
  print("Encrypted string: '" .. aesEncrypted .. "'")
  print("Decrypted string: '" .. aesDecrypted .. "'")
  assert(aesDecrypted == aesMessage)
  assert(aesEncrypted ~= aesMessage)

  local publicKey2, privateKey2 = crypto.newRsaKeyPair()
  local key2 = crypto.newAesKey()
  local encryptedKey = crypto.rsaEncrypt(publicKey2, key2)
  local decryptedKey = crypto.rsaDecrypt(privateKey2, encryptedKey)
  assert(key2 == decryptedKey)
  assert(key2 ~= encryptedKey)
end

local function test()
  print("Beginning tests")

  print("Testing encode message size...")
  testEncodeMessageSize()
  print("Testing decode message size...")
  testDecodeMessageSize()
  print("Testing crypto...")
  testCrypto()

  print("Completed tests")
end

test()
