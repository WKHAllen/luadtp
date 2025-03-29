local crypto = require("luadtp.cryptocore")

return {
  newRsaKeyPair = function ()
    local publicKey, privateKey = crypto.rsa_key_pair_new()

    if publicKey == nil or privateKey == nil then
      error("Failed generating RSA key pair, OpenSSL error: " .. crypto.get_openssl_error())
    end

    return publicKey, privateKey
  end,

  rsaEncrypt = function (publicKey, plaintext)
    local ciphertext = crypto.rsa_encrypt(publicKey, plaintext)

    if ciphertext == nil then
      error("Failed RSA encryption, OpenSSL error: " .. crypto.get_openssl_error())
    end

    return ciphertext
  end,

  rsaDecrypt = function (privateKey, ciphertext)
    local plaintext = crypto.rsa_decrypt(privateKey, ciphertext)

    if plaintext == nil then
      error("Failed RSA decryption, OpenSSL error: " .. crypto.get_openssl_error())
    end

    return plaintext
  end,

  newAesKey = function ()
    local key = crypto.aes_key_new()

    if key == nil then
      error("Failed generating AES key, OpenSSL error: " .. crypto.get_openssl_error())
    end

    return key
  end,

  aesEncrypt = function (key, plaintext)
    local ciphertext = crypto.aes_encrypt(key, plaintext)

    if ciphertext == nil then
      error("Failed AES encryption, OpenSSL error: " .. crypto.get_openssl_error())
    end

    return ciphertext
  end,

  aesDecrypt = function (key, ciphertext)
    local plaintext = crypto.aes_decrypt(key, ciphertext)

    if plaintext == nil then
      error("Failed AES decryption, OpenSSL error: " .. crypto.get_openssl_error())
    end

    return plaintext
  end,
}
