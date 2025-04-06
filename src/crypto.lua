local crypto = require("luadtp.cryptocore")

local function newRsaKeyPair()
  local publicKey, privateKey = crypto.rsa_key_pair_new()

  if publicKey == nil or privateKey == nil then
    error("Failed generating RSA key pair, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return publicKey, privateKey
end

local function rsaEncrypt(publicKey, plaintext)
  local ciphertext = crypto.rsa_encrypt(publicKey, plaintext)

  if ciphertext == nil then
    error("Failed RSA encryption, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return ciphertext
end

local function rsaDecrypt(privateKey, ciphertext)
  local plaintext = crypto.rsa_decrypt(privateKey, ciphertext)

  if plaintext == nil then
    error("Failed RSA decryption, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return plaintext
end

local function newAesKey()
  local key = crypto.aes_key_new()

  if key == nil then
    error("Failed generating AES key, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return key
end

local function aesEncrypt(key, plaintext)
  local ciphertext = crypto.aes_encrypt(key, plaintext)

  if ciphertext == nil then
    error("Failed AES encryption, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return ciphertext
end

local function aesDecrypt(key, ciphertext)
  local plaintext = crypto.aes_decrypt(key, ciphertext)

  if plaintext == nil then
    error("Failed AES decryption, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return plaintext
end

return {
  newRsaKeyPair = newRsaKeyPair,
  rsaEncrypt = rsaEncrypt,
  rsaDecrypt = rsaDecrypt,
  newAesKey = newAesKey,
  aesEncrypt = aesEncrypt,
  aesDecrypt = aesDecrypt,
}
