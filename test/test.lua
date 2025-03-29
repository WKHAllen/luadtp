local luadtp = require("luadtp")

local function testCrypto()
  local rsaMessage = "Hello, RSA!"
  local publicKey, privateKey = luadtp.crypto.newRsaKeyPair()
  local rsaEncrypted = luadtp.crypto.rsaEncrypt(publicKey, rsaMessage)
  local rsaDecrypted = luadtp.crypto.rsaDecrypt(privateKey, rsaEncrypted)
  print("Original string:  '" .. rsaMessage .. "'")
  print("Encrypted string: '" .. rsaEncrypted .. "'")
  print("Decrypted string: '" .. rsaDecrypted .. "'")
  assert(rsaDecrypted == rsaMessage)
  assert(rsaEncrypted ~= rsaMessage)

  local aesMessage = "Hello, AES!"
  local key = luadtp.crypto.newAesKey()
  local aesEncrypted = luadtp.crypto.aesEncrypt(key, aesMessage)
  local aesDecrypted = luadtp.crypto.aesDecrypt(key, aesEncrypted)
  print("Original string:  '" .. aesMessage .. "'")
  print("Encrypted string: '" .. aesEncrypted .. "'")
  print("Decrypted string: '" .. aesDecrypted .. "'")
  assert(aesDecrypted == aesMessage)
  assert(aesEncrypted ~= aesMessage)
end

local function test()
  print("Beginning tests")

  print("Testing crypto...")
  testCrypto()

  print("Completed tests")
end

test()
