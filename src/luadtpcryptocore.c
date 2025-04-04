#include <lua.h>
#include <lauxlib.h>
#include "luadtpcryptocore.h"

#include <stdlib.h>
#include <string.h>

#define BIO void
#define BIO_METHOD void
#define EVP_PKEY void
#define pem_password_cb void
#define OSSL_LIB_CTX void
#define EVP_CIPHER_CTX void
#define EVP_CIPHER void
#define ENGINE void

#define BIO_CTRL_PENDING 10

extern BIO *BIO_new(const BIO_METHOD *type);
extern BIO *BIO_new_mem_buf(const void *buf, int len);
extern const BIO_METHOD *BIO_s_mem(void);
extern long BIO_ctrl(BIO *bp, int cmd, long larg, void *parg);
extern int BIO_read(BIO *b, void *data, int dlen);
extern int BIO_free(BIO *a);
extern void BIO_free_all(BIO *a);
extern EVP_PKEY *PEM_read_bio_PUBKEY(BIO *bp, EVP_PKEY **x, pem_password_cb *cb,
                                     void *u);
extern EVP_PKEY *PEM_read_bio_PrivateKey(BIO *bp, EVP_PKEY **x,
                                         pem_password_cb *cb, void *u);
extern int PEM_write_bio_PUBKEY(BIO *bp, EVP_PKEY *x);
extern int PEM_write_bio_PrivateKey(BIO *bp, const EVP_PKEY *x,
                                    const EVP_CIPHER *enc, unsigned char *kstr,
                                    int klen, pem_password_cb *cb, void *u);
extern EVP_PKEY *EVP_PKEY_Q_keygen(OSSL_LIB_CTX *libctx, const char *propq,
                                   const char *type, ...);
extern int EVP_PKEY_get_size(const EVP_PKEY *pkey);
extern void EVP_PKEY_free(EVP_PKEY *key);
extern EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);
extern int EVP_CIPHER_CTX_get_block_size(const EVP_CIPHER_CTX *ctx);
extern void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *ctx);
extern const EVP_CIPHER *EVP_aes_256_cbc(void);
extern int EVP_CIPHER_get_iv_length(const EVP_CIPHER *e);
extern int EVP_SealInit(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *type,
                        unsigned char **ek, int *ekl, unsigned char *iv,
                        EVP_PKEY **pubk, int npubk);
extern int EVP_SealFinal(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl);
extern int EVP_OpenInit(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *type,
                        unsigned char *ek, int ekl, unsigned char *iv,
                        EVP_PKEY *priv);
extern int EVP_OpenFinal(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl);
extern int EVP_EncryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *type,
                              ENGINE *impl, const unsigned char *key,
                              const unsigned char *iv);
extern int EVP_EncryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out,
                             int *outl, const unsigned char *in, int inl);
extern int EVP_EncryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *out,
                               int *outl);
extern int EVP_DecryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *type,
                              ENGINE *impl, const unsigned char *key,
                              const unsigned char *iv);
extern int EVP_DecryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl,
                             const unsigned char *in, int inl);
extern int EVP_DecryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *outm,
                               int *outl);
extern int RAND_bytes(unsigned char *buf, int num);
extern unsigned long ERR_get_error(void);

#define BIO_pending(b) (int)BIO_ctrl(b, BIO_CTRL_PENDING, 0, NULL)
#define EVP_PKEY_size EVP_PKEY_get_size
#define EVP_CIPHER_CTX_block_size EVP_CIPHER_CTX_get_block_size
#define EVP_CIPHER_iv_length EVP_CIPHER_get_iv_length
#define EVP_RSA_gen(bits) \
    EVP_PKEY_Q_keygen(NULL, NULL, "RSA", (size_t)(0 + (bits)))
#define EVP_SealUpdate(a, b, c, d, e) EVP_EncryptUpdate(a, b, c, d, e)
#define EVP_OpenUpdate(a, b, c, d, e) EVP_DecryptUpdate(a, b, c, d, e)

// The length of the size portion of a message.
#define LENSIZE 5

// The RSA key size.
#define RSA_KEY_SIZE 2048

// The AES key size.
#define AES_KEY_SIZE 32

// The AES nonce size.
#define AES_NONCE_SIZE 16

/**
 * Generic data to be encrypted/decrypted.
 */
typedef struct crypto_data
{
    void *data;
    size_t data_size;
} crypto_data_t;

/**
 * An RSA public key.
 */
typedef struct rsa_public_key
{
    char *key;
    size_t key_size;
} rsa_public_key_t;

/**
 * An RSA private key.
 */
typedef struct rsa_private_key
{
    char *key;
    size_t key_size;
} rsa_private_key_t;

/**
 * An RSA key pair.
 */
typedef struct rsa_key_pair
{
    rsa_public_key_t *public_key;
    rsa_private_key_t *private_key;
} rsa_key_pair_t;

/**
 * An AES key.
 */
typedef struct aes_key
{
    char *key;
    size_t key_size;
} aes_key_t;

unsigned char *encode_message_size(size_t size)
{
    unsigned char *encoded_size = (unsigned char *)malloc(LENSIZE * sizeof(unsigned char));

    for (int i = LENSIZE - 1; i >= 0; i--)
    {
        encoded_size[i] = size % 256;
        size = size >> 8;
    }

    return encoded_size;
}

size_t decode_message_size(unsigned char *encoded_size)
{
    size_t size = 0;

    for (int i = 0; i < LENSIZE; i++)
    {
        size = size << 8;
        size += encoded_size[i];
    }

    return size;
}

/**
 * Create a generic piece of crypto data.
 *
 * @param data The data itself.
 * @param data_size The size of the data, in bytes.
 * @return The new crypto data object.
 *
 * Note that this makes its own copy of `data` and is not responsible for freeing it itself.
 */
crypto_data_t *crypto_data_new(void *data, size_t data_size)
{
    crypto_data_t *crypto_data = (crypto_data_t *)malloc(sizeof(crypto_data_t));

    crypto_data->data = malloc(data_size);
    memcpy(crypto_data->data, data, data_size);
    crypto_data->data_size = data_size;

    return crypto_data;
}

/**
 * Free the memory used by a piece of crypto data.
 *
 * @param crypto_data The crypto data.
 */
void crypto_data_free(crypto_data_t *crypto_data)
{
    free(crypto_data->data);
    free(crypto_data);
}

/**
 * Free the memory used by a piece of crypto data and get the inner data itself.
 *
 * @param crypto_data The crypto data.
 * @return The inner data.
 *
 * Note that `free` will need to be called on the returned data.
 */
void *crypto_data_unwrap(crypto_data_t *crypto_data)
{
    void *data = crypto_data->data;
    free(crypto_data);

    return data;
}

/**
 * Pad a section of bytes to ensure its size is never a multiple of 16 bytes. This alters the data in-place.
 *
 * @param crypto_data The data to pad.
 */
void pad_data(crypto_data_t *crypto_data)
{
    char *padded_data;

    if ((crypto_data->data_size + 1) % 16 == 0)
    {
        padded_data = malloc(crypto_data->data_size + 2);
        padded_data[0] = (char)1;
        padded_data[1] = (char)255;
        memcpy(padded_data + 2, crypto_data->data, crypto_data->data_size + 2);
        crypto_data->data_size += 2;
    }
    else
    {
        padded_data = malloc(crypto_data->data_size + 1);
        padded_data[0] = (char)0;
        memcpy(padded_data + 1, crypto_data->data, crypto_data->data_size + 1);
        crypto_data->data_size += 1;
    }

    free(crypto_data->data);
    crypto_data->data = (void *)padded_data;
}

/**
 * Unpad a section of padded bytes. This alters the data in-place.
 *
 * @param crypto_data The data to unpad.
 */
void unpad_data(crypto_data_t *crypto_data)
{
    char *unpadded_data;

    if (((char *)(crypto_data->data))[0] == ((char)1))
    {
        unpadded_data = malloc(crypto_data->data_size - 2);
        memcpy(unpadded_data, ((char *)(crypto_data->data)) + 2, crypto_data->data_size - 2);
        crypto_data->data_size -= 2;
    }
    else
    {
        unpadded_data = malloc(crypto_data->data_size - 1);
        memcpy(unpadded_data, ((char *)(crypto_data->data)) + 1, crypto_data->data_size - 1);
        crypto_data->data_size -= 1;
    }

    free(crypto_data->data);
    crypto_data->data = (void *)unpadded_data;
}

/**
 * Get an OpenSSL representation of a public key.
 *
 * @param public_key The public key.
 * @return The OpenSSL representation of the public key.
 */
EVP_PKEY *openssl_rsa_public_key(rsa_public_key_t *public_key)
{
    const char *pub_key = public_key->key;
    int pub_len = public_key->key_size;

    BIO *pbkeybio = NULL;

    if ((pbkeybio = BIO_new_mem_buf((const void *)pub_key, pub_len)) == NULL)
    {
        return NULL;
    }

    EVP_PKEY *pb_rsa = NULL;

    if ((pb_rsa = PEM_read_bio_PUBKEY(pbkeybio, &pb_rsa, NULL, NULL)) == NULL)
    {
        return NULL;
    }

    BIO_free(pbkeybio);

    return pb_rsa;
}

/**
 * Get an OpenSSL representation of a private key.
 *
 * @param private_key The private key.
 * @return The OpenSSL representation of the private key.
 */
EVP_PKEY *openssl_rsa_private_key(rsa_private_key_t *private_key)
{
    const char *pri_key = private_key->key;
    int pri_len = private_key->key_size;

    BIO *prkeybio = NULL;

    if ((prkeybio = BIO_new_mem_buf((const void *)pri_key, pri_len)) == NULL)
    {
        return NULL;
    }

    EVP_PKEY *p_rsa = NULL;

    if ((p_rsa = PEM_read_bio_PrivateKey(prkeybio, &p_rsa, NULL, NULL)) == NULL)
    {
        return NULL;
    }

    BIO_free(prkeybio);

    return p_rsa;
}

/**
 * Free the memory used by the OpenSSL public key.
 *
 * @param public_key The OpenSSL public key.
 */
void openssl_rsa_public_key_free(EVP_PKEY *public_key)
{
    EVP_PKEY_free(public_key);
}

/**
 * Free the memory used by the OpenSSL private key.
 *
 * @param private_key The OpenSSL private key.
 */
void openssl_rsa_private_key_free(EVP_PKEY *private_key)
{
    EVP_PKEY_free(private_key);
}

/**
 * Get a byte representation of an RSA public key.
 *
 * @param public_key The RSA public key.
 * @return The byte representation of the public key.
 */
crypto_data_t *rsa_public_key_to_bytes(rsa_public_key_t *public_key)
{
    return crypto_data_new(public_key->key, public_key->key_size);
}

/**
 * Get a byte representation of an RSA private key.
 *
 * @param private_key The RSA private key.
 * @return The byte representation of the private key.
 */
crypto_data_t *rsa_private_key_to_bytes(rsa_private_key_t *private_key)
{
    return crypto_data_new(private_key->key, private_key->key_size);
}

/**
 * Get a representation of a public key from the public key bytes.
 *
 * @param public_key_bytes The public key bytes.
 * @param public_key_size The size of the public key, in bytes.
 * @return The public key representation.
 *
 * Note that this makes its own copy of `public_key_bytes` and is not responsible for freeing it itself.
 */
rsa_public_key_t *rsa_public_key_from_bytes(char *public_key_bytes, size_t public_key_size)
{
    rsa_public_key_t *public_key = (rsa_public_key_t *)malloc(sizeof(rsa_public_key_t));

    public_key->key = (char *)malloc(public_key_size * sizeof(char));
    memcpy(public_key->key, public_key_bytes, public_key_size);
    public_key->key_size = public_key_size;

    return public_key;
}

/**
 * Get a representation of a private key from the private key bytes.
 *
 * @param private_key_bytes The private key bytes.
 * @param private_key_size The size of the private key, in bytes.
 * @return The private key representation.
 *
 * Note that this makes its own copy of `private_key_bytes` and is not responsible for freeing it itself.
 */
rsa_private_key_t *rsa_private_key_from_bytes(char *private_key_bytes, size_t private_key_size)
{
    rsa_private_key_t *private_key = (rsa_private_key_t *)malloc(sizeof(rsa_private_key_t));

    private_key->key = (char *)malloc(private_key_size * sizeof(char));
    memcpy(private_key->key, private_key_bytes, private_key_size);
    private_key->key_size = private_key_size;

    return private_key;
}

/**
 * Free the memory used by an RSA public key.
 *
 * @param public_key The RSA public key.
 */
void rsa_public_key_free(rsa_public_key_t *public_key)
{
    free(public_key->key);
    free(public_key);
}

/**
 * Free the memory used by an RSA private key.
 *
 * @param private_key The RSA private key.
 */
void rsa_private_key_free(rsa_private_key_t *private_key)
{
    free(private_key->key);
    free(private_key);
}

/**
 * Generate an RSA key pair.
 *
 * @return The generated key pair.
 */
rsa_key_pair_t *rsa_key_pair_new(void)
{
    EVP_PKEY *r;

    if ((r = EVP_RSA_gen((unsigned int)RSA_KEY_SIZE)) == NULL)
    {
        return NULL;
    }

    BIO *bp_public;
    BIO *bp_private;

    if ((bp_public = BIO_new(BIO_s_mem())) == NULL)
    {
        return NULL;
    }

    if (PEM_write_bio_PUBKEY(bp_public, r) == 0)
    {
        return NULL;
    }

    if ((bp_private = BIO_new(BIO_s_mem())) == NULL)
    {
        return NULL;
    }

    if (PEM_write_bio_PrivateKey(bp_private, r, NULL, NULL, 0, NULL, NULL) == 0)
    {
        return NULL;
    }

    size_t pub_len = BIO_pending(bp_public);
    size_t pri_len = BIO_pending(bp_private);
    char *public_key_bytes = (char *)malloc(pub_len * sizeof(char));
    char *private_key_bytes = (char *)malloc(pri_len * sizeof(char));

    if (BIO_read(bp_public, public_key_bytes, pub_len) < 1)
    {
        return NULL;
    }

    if (BIO_read(bp_private, private_key_bytes, pri_len) < 1)
    {
        return NULL;
    }

    BIO_free_all(bp_public);
    BIO_free_all(bp_private);
    EVP_PKEY_free(r);

    rsa_key_pair_t *key_pair = (rsa_key_pair_t *)malloc(sizeof(rsa_key_pair_t));

    key_pair->public_key = rsa_public_key_from_bytes(public_key_bytes, pub_len);
    key_pair->private_key = rsa_private_key_from_bytes(private_key_bytes, pri_len);

    free(public_key_bytes);
    free(private_key_bytes);

    return key_pair;
}

/**
 * Free the memory used by an RSA key pair.
 *
 * @param key_pair The RSA key pair.
 */
void rsa_key_pair_free(rsa_key_pair_t *key_pair)
{
    rsa_public_key_free(key_pair->public_key);
    rsa_private_key_free(key_pair->private_key);
    free(key_pair);
}

/**
 * Free the memory used by an RSA key pair wrapper.
 *
 * @param key_pair The RSA key pair.
 */
void rsa_key_pair_free_wrapper(rsa_key_pair_t *key_pair)
{
    free(key_pair);
}

/**
 * Encrypt data with RSA.
 *
 * @param public_key The RSA public key.
 * @param plaintext The data to encrypt.
 * @param plaintext_size The size of the data, in bytes.
 * @return A representation of the encrypted data.
 */
crypto_data_t *rsa_encrypt(rsa_public_key_t *public_key, void *plaintext, size_t plaintext_size)
{
    crypto_data_t *plaintext_padded = crypto_data_new(plaintext, plaintext_size);
    pad_data(plaintext_padded);
    unsigned char *plaintext_data = (unsigned char *)plaintext_padded->data;
    int plaintext_len = (int)plaintext_padded->data_size;

    EVP_PKEY *evp_public_key = openssl_rsa_public_key(public_key);

    int encrypted_key_len;

    int nonce_len = EVP_CIPHER_iv_length(EVP_aes_256_cbc());
    unsigned char *nonce = (unsigned char *)malloc(nonce_len * sizeof(unsigned char));

    if ((encrypted_key_len = EVP_PKEY_size(evp_public_key)) == 0)
    {
        return NULL;
    }

    unsigned char *encrypted_key = (unsigned char *)malloc(encrypted_key_len * sizeof(unsigned char));

    EVP_CIPHER_CTX *ctx;
    int ciphertext_len;
    int len;

    if ((ctx = EVP_CIPHER_CTX_new()) == NULL)
    {
        return NULL;
    }

    if (EVP_SealInit(ctx, EVP_aes_256_cbc(), &encrypted_key, &encrypted_key_len, nonce, &evp_public_key, 1) == 0)
    {
        return NULL;
    }

    int block_size = EVP_CIPHER_CTX_block_size(ctx);
    unsigned char *ciphertext_unsigned = (unsigned char *)malloc((plaintext_len + block_size - 1) * sizeof(unsigned char));

    len = plaintext_len + block_size - 1;

    if (EVP_SealUpdate(ctx, ciphertext_unsigned, &len, plaintext_data, plaintext_len) == 0)
    {
        return NULL;
    }

    ciphertext_len = len;

    if (EVP_SealFinal(ctx, ciphertext_unsigned + len, &len) == 0)
    {
        return NULL;
    }

    ciphertext_len += len;
    ciphertext_unsigned = realloc(ciphertext_unsigned, (size_t)ciphertext_len);

    unsigned char *all_unsigned = (unsigned char *)malloc((LENSIZE + encrypted_key_len + nonce_len + ciphertext_len) * sizeof(unsigned char));
    unsigned char *encoded_encrypted_key_len = encode_message_size((size_t)encrypted_key_len);
    memcpy(all_unsigned, encoded_encrypted_key_len, LENSIZE);
    memcpy(all_unsigned + LENSIZE, encrypted_key, encrypted_key_len);
    memcpy(all_unsigned + LENSIZE + encrypted_key_len, nonce, nonce_len);
    memcpy(all_unsigned + LENSIZE + encrypted_key_len + nonce_len, ciphertext_unsigned, ciphertext_len);

    EVP_CIPHER_CTX_free(ctx);
    openssl_rsa_public_key_free(evp_public_key);

    crypto_data_t *ciphertext = crypto_data_new((void *)all_unsigned, LENSIZE + encrypted_key_len + nonce_len + ciphertext_len);

    crypto_data_free(plaintext_padded);
    free(nonce);
    free(encrypted_key);
    free(ciphertext_unsigned);
    free(all_unsigned);
    free(encoded_encrypted_key_len);

    return ciphertext;
}

/**
 * Decrypt data with RSA.
 *
 * @param private_key The RSA private key.
 * @param ciphertext The data to decrypt.
 * @param ciphertext_size The size of the data, in bytes.
 * @return A representation of the decrypted data.
 */
crypto_data_t *rsa_decrypt(rsa_private_key_t *private_key, void *ciphertext, size_t ciphertext_size)
{
    EVP_PKEY *evp_private_key = openssl_rsa_private_key(private_key);
    int nonce_len = EVP_CIPHER_iv_length(EVP_aes_256_cbc());

    unsigned char *all_unsigned = (unsigned char *)ciphertext;

    char *encoded_encrypted_key_len = (char *)malloc(LENSIZE * sizeof(char));
    memcpy(encoded_encrypted_key_len, all_unsigned, LENSIZE);

    int encrypted_key_len = (int)decode_message_size((unsigned char *)encoded_encrypted_key_len);

    unsigned char *encrypted_key = (unsigned char *)malloc(encrypted_key_len * sizeof(unsigned char));
    memcpy(encrypted_key, all_unsigned + LENSIZE, encrypted_key_len);

    unsigned char *nonce = (unsigned char *)malloc(nonce_len * sizeof(unsigned char *));
    memcpy(nonce, all_unsigned + LENSIZE + encrypted_key_len, nonce_len);

    int ciphertext_len = ciphertext_size - (LENSIZE + encrypted_key_len + nonce_len);

    unsigned char *ciphertext_unsigned = (unsigned char *)malloc(ciphertext_len * sizeof(unsigned char));
    memcpy(ciphertext_unsigned, all_unsigned + LENSIZE + encrypted_key_len + nonce_len, ciphertext_len);

    EVP_CIPHER_CTX *ctx;
    int len;
    int plaintext_len;

    if ((ctx = EVP_CIPHER_CTX_new()) == NULL)
    {
        return NULL;
    }

    if (EVP_OpenInit(ctx, EVP_aes_256_cbc(), encrypted_key, encrypted_key_len, nonce, evp_private_key) == 0)
    {
        return NULL;
    }

    unsigned char *plaintext_unsigned = (unsigned char *)malloc(ciphertext_len * sizeof(unsigned char));

    if (EVP_OpenUpdate(ctx, plaintext_unsigned, &len, ciphertext_unsigned, ciphertext_len) == 0)
    {
        return NULL;
    }

    plaintext_len = len;

    if (EVP_OpenFinal(ctx, plaintext_unsigned + len, &len) == 0)
    {
        return NULL;
    }

    plaintext_len += len;
    plaintext_unsigned = realloc(plaintext_unsigned, (size_t)plaintext_len);

    crypto_data_t *plaintext = crypto_data_new(plaintext_unsigned, plaintext_len);
    unpad_data(plaintext);

    EVP_CIPHER_CTX_free(ctx);
    openssl_rsa_private_key_free(evp_private_key);

    free(encoded_encrypted_key_len);
    free(encrypted_key);
    free(nonce);
    free(ciphertext_unsigned);
    free(plaintext_unsigned);

    return plaintext;
}

/**
 * Generate an AES key.
 *
 * @return The generated key.
 */
aes_key_t *aes_key_new(void)
{
    unsigned char key_unsigned[AES_KEY_SIZE];

    if (RAND_bytes(key_unsigned, AES_KEY_SIZE) == 0)
    {
        return NULL;
    }

    aes_key_t *key = (aes_key_t *)malloc(sizeof(aes_key_t));

    key->key = (char *)malloc(AES_KEY_SIZE * sizeof(char));
    memcpy(key->key, key_unsigned, AES_KEY_SIZE);
    key->key_size = AES_KEY_SIZE;

    return key;
}

/**
 * Free the memory used by an AES key.
 *
 * @param key The AES key.
 */
void aes_key_free(aes_key_t *key)
{
    free(key->key);
    free(key);
}

/**
 * Create an AES key from bytes.
 *
 * @param bytes The key data.
 * @param size The size of the key data, in bytes.
 * @return The AES key.
 */
aes_key_t *aes_key_from_bytes(char *bytes, size_t size)
{
    aes_key_t *key = (aes_key_t *)malloc(sizeof(aes_key_t));

    key->key = (char *)malloc(size);
    memcpy(key->key, bytes, size);
    key->key_size = size;

    return key;
}

/**
 * Encrypt data with AES.
 *
 * @param key The AES key.
 * @param plaintext The data to encrypt.
 * @param plaintext_size The size of the data, in bytes.
 * @return A representation of the encrypted data.
 */
crypto_data_t *aes_encrypt(aes_key_t *key, void *plaintext, size_t plaintext_size)
{
    unsigned char *key_unsigned = (unsigned char *)key->key;
    unsigned char nonce_unsigned[AES_KEY_SIZE];

    if (RAND_bytes(nonce_unsigned, AES_KEY_SIZE) == 0)
    {
        return NULL;
    }

    crypto_data_t *plaintext_padded = crypto_data_new(plaintext, plaintext_size);
    pad_data(plaintext_padded);
    unsigned char *plaintext_data = (unsigned char *)plaintext_padded->data;
    int plaintext_len = (int)plaintext_padded->data_size;

    EVP_CIPHER_CTX *ctx;
    int len;
    int ciphertext_len;

    if ((ctx = EVP_CIPHER_CTX_new()) == NULL)
    {
        return NULL;
    }

    if (EVP_EncryptInit_ex(ctx, EVP_aes_256_cbc(), NULL, key_unsigned, nonce_unsigned) == 0)
    {
        return NULL;
    }

    int block_size = EVP_CIPHER_CTX_block_size(ctx);
    unsigned char *ciphertext_unsigned = (unsigned char *)malloc((plaintext_len + block_size - 1) * sizeof(unsigned char));

    len = plaintext_len + block_size - 1;

    if (EVP_EncryptUpdate(ctx, ciphertext_unsigned, &len, plaintext_data, plaintext_len) == 0)
    {
        return NULL;
    }

    ciphertext_len = len;

    if (EVP_EncryptFinal_ex(ctx, ciphertext_unsigned + len, &len) == 0)
    {
        return NULL;
    }

    ciphertext_len += len;
    ciphertext_unsigned = realloc(ciphertext_unsigned, (size_t)ciphertext_len);
    unsigned char *ciphertext_with_nonce_unsigned = (unsigned char *)malloc((AES_NONCE_SIZE + ciphertext_len) * sizeof(unsigned char));
    memcpy(ciphertext_with_nonce_unsigned, nonce_unsigned, AES_NONCE_SIZE);
    memcpy(ciphertext_with_nonce_unsigned + AES_NONCE_SIZE, ciphertext_unsigned, ciphertext_len);
    crypto_data_t *ciphertext_with_nonce = crypto_data_new((void *)ciphertext_with_nonce_unsigned, AES_NONCE_SIZE + ciphertext_len);

    EVP_CIPHER_CTX_free(ctx);

    crypto_data_free(plaintext_padded);
    free(ciphertext_unsigned);
    free(ciphertext_with_nonce_unsigned);

    return ciphertext_with_nonce;
}

/**
 * Decrypt data with AES.
 *
 * @param key The AES key.
 * @param ciphertext The data to decrypt.
 * @param ciphertext_size The size of the data, in bytes.
 * @return A representation of the decrypted data.
 */
crypto_data_t *aes_decrypt(aes_key_t *key, void *ciphertext, size_t ciphertext_size)
{
    unsigned char *key_unsigned = (unsigned char *)key->key;
    unsigned char nonce_unsigned[AES_NONCE_SIZE];
    memcpy(nonce_unsigned, ciphertext, AES_NONCE_SIZE);
    unsigned char *ciphertext_data = (unsigned char *)malloc((ciphertext_size - AES_NONCE_SIZE) * sizeof(unsigned char));
    memcpy(ciphertext_data, ((char *)ciphertext) + AES_NONCE_SIZE, ciphertext_size - AES_NONCE_SIZE);
    int ciphertext_len = (int)(ciphertext_size - AES_NONCE_SIZE);

    EVP_CIPHER_CTX *ctx;
    int len;
    int plaintext_len;

    if ((ctx = EVP_CIPHER_CTX_new()) == NULL)
    {
        return NULL;
    }

    if (EVP_DecryptInit_ex(ctx, EVP_aes_256_cbc(), NULL, key_unsigned, nonce_unsigned) == 0)
    {
        return NULL;
    }

    unsigned char *plaintext_unsigned = (unsigned char *)malloc(ciphertext_len * sizeof(unsigned char));

    if (EVP_DecryptUpdate(ctx, plaintext_unsigned, &len, ciphertext_data, ciphertext_len) == 0)
    {
        return NULL;
    }

    plaintext_len = len;

    if (EVP_DecryptFinal_ex(ctx, plaintext_unsigned + len, &len) == 0)
    {
        return NULL;
    }

    plaintext_len += len;
    plaintext_unsigned = realloc(plaintext_unsigned, (size_t)plaintext_len);
    crypto_data_t *plaintext = crypto_data_new((void *)plaintext_unsigned, plaintext_len);
    unpad_data(plaintext);

    EVP_CIPHER_CTX_free(ctx);

    free(ciphertext_data);
    free(plaintext_unsigned);

    return plaintext;
}

/**
 * Gets the most recent OpenSSL error.
 *
 * @return The error code.
 */
unsigned long get_openssl_error(void)
{
    return ERR_get_error();
}

#include <stdio.h>

static int l_rsa_key_pair_new(lua_State *L)
{
    printf("l_rsa_key_pair_new\n");
    fflush(stdout);
    rsa_key_pair_t *key_pair = rsa_key_pair_new();
    printf("Public key size: %d\n", (int)(key_pair->public_key->key_size));
    for (size_t i = 0; i < key_pair->public_key->key_size; i++)
        printf("%c", key_pair->public_key->key[i]);
    printf("\n");
    fflush(stdout);
    printf("Private key size: %d\n", (int)(key_pair->private_key->key_size));
    for (size_t i = 0; i < key_pair->private_key->key_size; i++)
        printf("%c", key_pair->private_key->key[i]);
    printf("\n");
    fflush(stdout);

    if (key_pair == NULL)
    {
        lua_pushnil(L);
        lua_pushnil(L);
    }
    else
    {
        lua_pushlstring(L, (const char *)(key_pair->public_key->key), key_pair->public_key->key_size);
        lua_pushlstring(L, (const char *)(key_pair->private_key->key), key_pair->private_key->key_size);
        rsa_key_pair_free(key_pair);
    }

    return 2;
}

static int l_rsa_encrypt(lua_State *L)
{
    printf("<l_rsa_encrypt>\n");
    fflush(stdout);
    rsa_public_key_t public_key;
    public_key.key = (char *)luaL_checklstring(L, 1, &(public_key.key_size));
    printf("Public key size: %d\n", (int)(public_key.key_size));
    for (size_t i = 0; i < public_key.key_size; i++)
        printf("%c", public_key.key[i]);
    printf("\n");
    fflush(stdout);
    size_t plaintext_size;
    void *plaintext = (void *)luaL_checklstring(L, 2, &plaintext_size);
    printf("Plaintext size: %d\n", (int)(plaintext_size));
    for (size_t i = 0; i < plaintext_size; i++)
        printf("%c", ((char *)(plaintext))[i]);
    printf("\n");
    fflush(stdout);
    crypto_data_t *ciphertext = rsa_encrypt(&public_key, plaintext, plaintext_size);
    printf("Ciphertext size: %d\n", (int)(ciphertext->data_size));
    for (size_t i = 0; i < ciphertext->data_size; i++)
        printf("%c", ((char *)(ciphertext->data))[i]);
    printf("\n");
    fflush(stdout);

    if (ciphertext == NULL)
    {
        lua_pushnil(L);
    }
    else
    {
        lua_pushlstring(L, (const char *)(ciphertext->data), ciphertext->data_size);
        crypto_data_free(ciphertext);
    }
    printf("</l_rsa_encrypt>\n");

    return 1;
}

static int l_rsa_decrypt(lua_State *L)
{
    rsa_private_key_t private_key;
    private_key.key = (char *)luaL_checklstring(L, 1, &(private_key.key_size));
    size_t ciphertext_size;
    void *ciphertext = (void *)luaL_checklstring(L, 2, &ciphertext_size);
    crypto_data_t *plaintext = rsa_decrypt(&private_key, ciphertext, ciphertext_size);

    if (plaintext == NULL)
    {
        lua_pushnil(L);
    }
    else
    {
        lua_pushlstring(L, (const char *)(plaintext->data), plaintext->data_size);
        crypto_data_free(plaintext);
    }

    return 1;
}

static int l_aes_key_new(lua_State *L)
{
    aes_key_t *key = aes_key_new();

    if (key == NULL)
    {
        lua_pushnil(L);
    }
    else
    {
        lua_pushlstring(L, (const char *)(key->key), key->key_size);
        aes_key_free(key);
    }

    return 1;
}

static int l_aes_encrypt(lua_State *L)
{
    aes_key_t key;
    key.key = (char *)luaL_checklstring(L, 1, &(key.key_size));
    size_t plaintext_size;
    void *plaintext = (void *)luaL_checklstring(L, 2, &plaintext_size);
    crypto_data_t *ciphertext = aes_encrypt(&key, plaintext, plaintext_size);

    if (ciphertext == NULL)
    {
        lua_pushnil(L);
    }
    else
    {
        lua_pushlstring(L, (const char *)(ciphertext->data), ciphertext->data_size);
        crypto_data_free(ciphertext);
    }

    return 1;
}

static int l_aes_decrypt(lua_State *L)
{
    aes_key_t key;
    key.key = (char *)luaL_checklstring(L, 1, &(key.key_size));
    size_t ciphertext_size;
    void *ciphertext = (void *)luaL_checklstring(L, 2, &ciphertext_size);
    crypto_data_t *plaintext = aes_decrypt(&key, ciphertext, ciphertext_size);

    if (plaintext == NULL)
    {
        lua_pushnil(L);
    }
    else
    {
        lua_pushlstring(L, (const char *)(plaintext->data), plaintext->data_size);
        crypto_data_free(plaintext);
    }

    return 1;
}

static int l_get_openssl_error(lua_State *L)
{
    unsigned long err = get_openssl_error();
    lua_pushinteger(L, err);
    return 1;
}

static const struct luaL_Reg luadtpcryptocorelib[] = {
    {"rsa_key_pair_new", l_rsa_key_pair_new},
    {"rsa_encrypt", l_rsa_encrypt},
    {"rsa_decrypt", l_rsa_decrypt},
    {"aes_key_new", l_aes_key_new},
    {"aes_encrypt", l_aes_encrypt},
    {"aes_decrypt", l_aes_decrypt},
    {"get_openssl_error", l_get_openssl_error},
    {NULL, NULL}};

LUADTPCRYPTOCORE_API int luaopen_luadtp_cryptocore(lua_State *L)
{
    luaL_newlib(L, luadtpcryptocorelib);
    return 1;
}
