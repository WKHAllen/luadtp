local crypto = require("luadtp.cryptocore")

---Generates a new RSA key pair.
---@return string # The RSA public key.
---@return string # The RSA private key.
local function newRsaKeyPair()
  local publicKey, privateKey = crypto.rsa_key_pair_new()

  if publicKey == nil or privateKey == nil then
    error("Failed generating RSA key pair, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return publicKey, privateKey
end

---Performs an RSA encryption.
---@param publicKey string The RSA public key.
---@param plaintext string The plaintext data to encrypt.
---@return string # The encrypted ciphertext.
local function rsaEncrypt(publicKey, plaintext)
  local ciphertext = crypto.rsa_encrypt(publicKey, plaintext)

  if ciphertext == nil then
    error("Failed RSA encryption, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return ciphertext
end

---Performs an RSA decryption.
---@param privateKey string The RSA private key.
---@param ciphertext string The ciphertext data to decrypt.
---@return string # The decrypted plaintext.
local function rsaDecrypt(privateKey, ciphertext)
  local plaintext = crypto.rsa_decrypt(privateKey, ciphertext)

  if plaintext == nil then
    error("Failed RSA decryption, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return plaintext
end

---Generates a new AES key.
---@return string # The AES key.
local function newAesKey()
  local key = crypto.aes_key_new()

  if key == nil then
    error("Failed generating AES key, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return key
end

---Performs an AES encryption.
---@param key string The AES key.
---@param plaintext string The plaintext to encrypt.
---@return string # The encrypted ciphertext.
local function aesEncrypt(key, plaintext)
  local ciphertext = crypto.aes_encrypt(key, plaintext)

  if ciphertext == nil then
    error("Failed AES encryption, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return ciphertext
end

---Performs an AES decryption.
---@param key string The AES key.
---@param ciphertext string The ciphertext to decrypt.
---@return string # The decrypted plaintext.
local function aesDecrypt(key, ciphertext)
  local plaintext = crypto.aes_decrypt(key, ciphertext)

  if plaintext == nil then
    error("Failed AES decryption, OpenSSL error: " .. crypto.get_openssl_error())
  end

  return plaintext
end

---Sleeps for a given duration of time.
---@param seconds number The number of seconds to sleep.
local function sleep(seconds)
  crypto.sleep(seconds)
end

return {
  newRsaKeyPair = newRsaKeyPair,
  rsaEncrypt = rsaEncrypt,
  rsaDecrypt = rsaDecrypt,
  newAesKey = newAesKey,
  aesEncrypt = aesEncrypt,
  aesDecrypt = aesDecrypt,
  sleep = sleep,
}
