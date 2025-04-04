local luadtp = require("luadtp")

local function testCrypto()
  local rsaMessage = "Hello, RSA!"
  print("Generating RSA key pair...")
  local publicKey, privateKey = luadtp.crypto.newRsaKeyPair()
  print("Performing RSA encryption...")
  local rsaEncrypted = luadtp.crypto.rsaEncrypt(publicKey, rsaMessage)
  print("Performing RSA decryption...")
  local rsaDecrypted = luadtp.crypto.rsaDecrypt(privateKey, rsaEncrypted)
  print("Original string:  '" .. rsaMessage .. "'")
  print("Encrypted string: '" .. rsaEncrypted .. "'")
  print("Decrypted string: '" .. rsaDecrypted .. "'")
  assert(rsaDecrypted == rsaMessage)
  assert(rsaEncrypted ~= rsaMessage)

  local aesMessage = "Hello, AES!"
  print("Generating AES key...")
  local key = luadtp.crypto.newAesKey()
  print("Performing AES encryption...")
  local aesEncrypted = luadtp.crypto.aesEncrypt(key, aesMessage)
  print("Performing AES decryption...")
  local aesDecrypted = luadtp.crypto.aesDecrypt(key, aesEncrypted)
  print("Original string:  '" .. aesMessage .. "'")
  print("Encrypted string: '" .. aesEncrypted .. "'")
  print("Decrypted string: '" .. aesDecrypted .. "'")
  assert(aesDecrypted == aesMessage)
  assert(aesEncrypted ~= aesMessage)

  print("Generating RSA key pair...")
  local publicKey2, privateKey2 = luadtp.crypto.newRsaKeyPair()
  print("Generating AES key...")
  local key2 = luadtp.crypto.newAesKey()
  print("Encrypting AES key with RSA...")
  local encryptedKey = luadtp.crypto.rsaEncrypt(publicKey2, key2)
  print("Decrypting AES key with RSA...")
  local decryptedKey = luadtp.crypto.rsaDecrypt(privateKey2, encryptedKey)
  assert(key2 == decryptedKey)
  assert(key2 ~= encryptedKey)
end

local function test()
  print("Beginning tests")

  print("Testing crypto...")
  testCrypto()

  print("Completed tests")
end

test()
