/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"
# include "lmtoptional.h"

/*
    This optional is not yet officially supported and mostly serves as playground. One problem with 
    certificates like this is that one cannot use letsencrypt (and similar free) certificates but 
    has to go for expensive, vendor locked in ones. Also, in viewers like acribat root certificates
    are compiled in so ... in the end it's all not that useful in pdf in the perspective of open 
    and free software. 

    It tooks a bit of work to get the (in the end not that much) code because searching online gives 
    confusing and even wrong results. So in the end it came down to looking into openssl and a bit of 
    trial and error. Therefore the following code is likely to evolve. 
*/

typedef void * BIO;
typedef void * EVP_PKEY;
typedef void * X509;
typedef void * X509_STORE;
typedef void * pem_password_cb;
typedef void * PKCS7;
typedef void * OPENSSL_STACK;

typedef struct openssllib_state_info {

    int initialized;
    int padding;

    void (*OPENSSL_init_ssl) (
        int, 
        void *
    );

    PKCS7 * (*PKCS7_sign) (
        X509          *signcert,
        EVP_PKEY      *pkey,
        X509         **certs,    
        BIO           *data,
        unsigned int   flags
    );

    int (*PKCS7_final) (
        PKCS7 *p7, 
        BIO   *data, 
        int    flags
    );

    int (*i2d_PKCS7) (
        BIO            *bp, 
        unsigned char **ppout
    );

    int (*i2d_PKCS7_DIGEST) (
        BIO            *bp, 
        unsigned char **ppout
    );

    int (*i2d_PKCS7_bio) (
        BIO   *bp, 
        PKCS7 *a
    );

    int (*SMIME_write_PKCS7) (
        BIO   *out,
        PKCS7 *p7,
        BIO   *data,
        int    flags
    );

    void (*PKCS7_free) (
        void *
    );

    void (*X509_free) (
        void *
    );

    void (*EVP_PKEY_free) (
        void *
    );

    void * (*BIO_new_file) (
        const char *filename,
        const char *mode
    );

    void * (*BIO_new_mem_buf) (
        const char *data,
        int         size
    );

 // int (*BIO_reset) (
 //     void *
 // );

    long (*BIO_ctrl) (
        BIO  *bp, 
        int   cmd, 
        long  larg, 
        void *parg
    );

    void (*BIO_free) (
        void *
    );

    X509 * (*PEM_read_bio_X509) (
        BIO             *bp,
        X509            **x, 
        pem_password_cb *cb, 
        const char       *u  
    );
    
    EVP_PKEY * (*PEM_read_bio_PrivateKey) (
        BIO              *bp,
        EVP_PKEY        **x,  
        pem_password_cb  *cb, 
        const char       *u   
    );

    int (*PKCS7_verify) (
        PKCS7      *p7, 
        X509       *certs, // stack 
        X509_STORE *store, 
        BIO        *indata, 
        BIO        *out, 
        int         flags
    );

    int (*d2i_PKCS7) (
        PKCS7      **a, 
        const char **ppin, // constant unsigned char 
        long         length
    );

    int (*d2i_PKCS7_DIGEST) (
        PKCS7      **a, 
        const char **ppin, // constant unsigned char 
        long         length
    );

 // OPENSSL_STACK (*OPENSSL_sk_new_null) (
 //     void
 // );
 //
 // int (*OPENSSL_sk_push) (
 //     OPENSSL_STACK *st, 
 //     const void    *data
 // );
 //
 // void (*OPENSSL_sk_free) (
 //     OPENSSL_STACK *st
 // );

} openssllib_state_info;

# define BIO_CTRL_RESET  1 /* opt - rewind/zero etc */
# define BIO_CTRL_INFO   3 /* opt - extra tit-bits */

# define PKCS7_DETACHED 0x0040
# define PKCS7_BINARY   0x0080
# define PKCS7_STREAM   0x1000

# define PKCS7_NOINTERN 0x0010
# define PKCS7_NOVERIFY 0x0020

# define SSL_library_init()     openssllib_state.OPENSSL_init_ssl(0, NULL)
# define BIO_reset(b)           openssllib_state.BIO_ctrl(b,BIO_CTRL_RESET,0,NULL)
# define BIO_get_mem_data(b,pp) openssllib_state.BIO_ctrl(b,BIO_CTRL_INFO,0,(char *)(pp))

static openssllib_state_info openssllib_state = {

    .initialized             = 0,
    .padding                 = 0,

    .OPENSSL_init_ssl        = NULL,
    .PKCS7_sign              = NULL,   
    .PKCS7_final             = NULL,   
    .i2d_PKCS7               = NULL,
    .i2d_PKCS7_bio           = NULL,
 // .SMIME_write_PKCS7       = NULL,
    .PKCS7_free              = NULL,
    .X509_free               = NULL,
    .EVP_PKEY_free           = NULL,
    .BIO_new_file            = NULL,
    .BIO_new_mem_buf         = NULL,
    .BIO_ctrl                = NULL,
    .BIO_free                = NULL,
    .PEM_read_bio_X509       = NULL,
    .PEM_read_bio_PrivateKey = NULL,
    .PKCS7_verify            = NULL,
    .d2i_PKCS7               = NULL,
    .d2i_PKCS7_DIGEST        = NULL,
 // .OPENSSL_sk_new_null     = NULL,
 // .OPENSSL_sk_push         = NULL,
 // .OPENSSL_sk_free         = NULL,

};

static int openssllib_initialize(lua_State * L)
{
    if (! openssllib_state.initialized) {
        const char *filename_c = lua_tostring(L, 1);
        const char *filename_s = lua_tostring(L, 2);
        if (filename_c && filename_s) {

            lmt_library lib_c = lmt_library_load(filename_c);
            lmt_library lib_s = lmt_library_load(filename_s);

            openssllib_state.OPENSSL_init_ssl        = lmt_library_find(lib_s, "OPENSSL_init_ssl");

            openssllib_state.PKCS7_sign              = lmt_library_find(lib_c, "PKCS7_sign");
            openssllib_state.PKCS7_final             = lmt_library_find(lib_c, "PKCS7_final");
            openssllib_state.i2d_PKCS7               = lmt_library_find(lib_c, "i2d_PKCS7");
            openssllib_state.i2d_PKCS7_bio           = lmt_library_find(lib_c, "i2d_PKCS7_bio");
         // openssllib_state.SMIME_write_PKCS7       = lmt_library_find(lib_c, "SMIME_write_PKCS7");
            openssllib_state.PKCS7_free              = lmt_library_find(lib_c, "PKCS7_free");

            openssllib_state.X509_free               = lmt_library_find(lib_c, "X509_free");
            openssllib_state.EVP_PKEY_free           = lmt_library_find(lib_c, "EVP_PKEY_free");
            openssllib_state.BIO_new_file            = lmt_library_find(lib_c, "BIO_new_file");
            openssllib_state.BIO_new_mem_buf         = lmt_library_find(lib_c, "BIO_new_mem_buf");
            openssllib_state.BIO_ctrl                = lmt_library_find(lib_c, "BIO_ctrl");
            openssllib_state.BIO_free                = lmt_library_find(lib_c, "BIO_free");
            openssllib_state.PEM_read_bio_X509       = lmt_library_find(lib_c, "PEM_read_bio_X509");
            openssllib_state.PEM_read_bio_PrivateKey = lmt_library_find(lib_c, "PEM_read_bio_PrivateKey");

            openssllib_state.PKCS7_verify            = lmt_library_find(lib_c, "PKCS7_verify");
            openssllib_state.d2i_PKCS7               = lmt_library_find(lib_c, "d2i_PKCS7");
            openssllib_state.d2i_PKCS7_DIGEST        = lmt_library_find(lib_c, "d2i_PKCS7_DIGEST");

         // openssllib_state.OPENSSL_sk_new_null     = lmt_library_find(lib_c, "OPENSSL_sk_new_null");
         // openssllib_state.OPENSSL_sk_push         = lmt_library_find(lib_c, "OPENSSL_sk_push");
         // openssllib_state.OPENSSL_sk_free         = lmt_library_find(lib_c, "OPENSSL_sk_free");

            openssllib_state.initialized = lmt_library_okay(lib_s) && lmt_library_okay(lib_c);

            openssllib_state.OPENSSL_init_ssl(0, NULL);
        }
    }
    lua_pushboolean(L, openssllib_state.initialized);
    return 1;
}

/*tex
    Let's save some bytes and delegate the error strings to the \LUA\ module. 
*/

typedef enum messages {
    m_all_is_okay,
    m_invalid_certificate_file,
    m_invalid_certificate,
    m_invalid_private_key,
    m_invalid_data_file,
    m_invalid_signature,
    m_unable_to_open_output_file,
    m_unable_to_reset_file,
    m_unable_to_save_signature,
    m_incomplete_specification,
    m_library_is_unitialized,
} messages;

/* 
    We could zero the password but who knows what is kept in memory by openssl. We just 
    assume a safe server. 
*/

static int openssllib_sign(lua_State * L)
{
    int message = m_all_is_okay;
    if (openssllib_state.initialized) {
        if (lua_type(L, 1) == LUA_TTABLE) {
            const char *certfile = NULL;
            const char *datafile = NULL;
            const char *password = NULL;
            const char *resultfile = NULL;
            const char *data = NULL;
            unsigned char *resultdata = NULL;
            size_t datasize = 0;
            size_t resultsize = 0;
            if (lua_getfield(L, 1, "certfile")   == LUA_TSTRING) { certfile   = lua_tostring (L, -1);            } lua_pop(L, 1);
            if (lua_getfield(L, 1, "datafile")   == LUA_TSTRING) { datafile   = lua_tostring (L, -1);            } lua_pop(L, 1);
            if (lua_getfield(L, 1, "data")       == LUA_TSTRING) { data       = lua_tolstring(L, -1, &datasize); } lua_pop(L, 1);
            if (lua_getfield(L, 1, "password")   == LUA_TSTRING) { password   = lua_tostring (L, -1);            } lua_pop(L, 1);
            if (lua_getfield(L, 1, "resultfile") == LUA_TSTRING) { resultfile = lua_tostring (L, -1);            } lua_pop(L, 1);
            if (certfile && password && (data || datafile)) {
                int okay = 0;
                BIO *input = NULL;
                BIO *output = NULL;
                BIO *certificate = NULL;
                X509 *x509 = NULL;
                EVP_PKEY *key = NULL;
                PKCS7 *p7 = NULL;
                int flags = PKCS7_DETACHED | PKCS7_STREAM | PKCS7_BINARY; /* without PKCS7_STREAM we crash */
                certificate = openssllib_state.BIO_new_file(certfile, "rb");
                if (! certificate) {
                    message = m_invalid_certificate_file;
                    goto DONE;
                }
                x509 = openssllib_state.PEM_read_bio_X509(certificate, NULL, NULL, password);
                if (! x509) {
                    message = m_invalid_certificate;
                    goto DONE;
                }
                if (BIO_reset(certificate) < 0) {
                    message = m_unable_to_reset_file;
                    goto DONE;
                }
                key = openssllib_state.PEM_read_bio_PrivateKey(certificate, NULL, NULL, password);
                if (! key) {
                    message = m_invalid_private_key;
                    goto DONE;
                }
                if (datafile) { 
                    input = openssllib_state.BIO_new_file(datafile, "rb");
                } else { 
                    input = openssllib_state.BIO_new_mem_buf(data, (int) datasize);
                }
                if (! input) {
                    message = m_invalid_data_file;
                    goto DONE;
                }
                p7 = openssllib_state.PKCS7_sign(x509, key, NULL, input, flags);
                if (! p7) {
                    message = m_invalid_signature;
                    goto DONE;
                }
                openssllib_state.PKCS7_final(p7, input, flags);
                if (resultfile) { 
                    output = openssllib_state.BIO_new_file(resultfile, "wb");
                    if (! output) {
                        message = m_unable_to_open_output_file;
                        goto DONE;
                    }
                 // if (! (flags & CMS_STREAM) && (BIO_reset(input) < 0)) { // no need to reset 
                 //     message = m_unable_to_reset_file;
                 //     goto DONE;
                 // }
                 // if (! openssllib_state.SMIME_write_PKCS7(output, p7, input, flags)) {
                    if (! openssllib_state.i2d_PKCS7_bio(output, p7)) {
                        message = m_unable_to_save_signature;
                        goto DONE;
                    }
                } else {
                    resultsize = openssllib_state.i2d_PKCS7(p7, &resultdata);
                }
                okay = 1;
              DONE:
                if (certificate) { openssllib_state.BIO_free(certificate); }
                if (x509)        { openssllib_state.X509_free(x509);       }
                if (p7)          { openssllib_state.PKCS7_free(p7);        }
                if (key)         { openssllib_state.EVP_PKEY_free(key);    }
                if (input)       { openssllib_state.BIO_free(input);       }
                if (output)      { openssllib_state.BIO_free(output);      }
                if (okay) {
                    if (resultdata && resultsize > 0) {
                        lua_pushboolean(L, 1);
                        lua_pushlstring(L, (const char *) resultdata, resultsize);
                        return 2;
                    } else { 
                        return 1;
                    }
                }
            }
        } else { 
            message = m_incomplete_specification;
        }
    } else { 
        message = m_library_is_unitialized;
    }
    lua_pushboolean(L, 0);
    if (message) { 
        lua_pushinteger(L, message);
        return 2;
    } else { 
        return 1;
    }
}

static int openssllib_verify(lua_State * L)
{
    int message = m_all_is_okay;
    if (openssllib_state.initialized) {
        const char *certfile = NULL;
        const char *datafile = NULL;
        const char *password = NULL;
        const char *signature = NULL;
        const char *data = NULL;
        size_t signaturesize = 0;
        size_t datasize = 0;
        if (lua_getfield(L, 1, "certfile")  == LUA_TSTRING) { certfile  = lua_tostring (L, -1);                 } lua_pop(L, 1);
        if (lua_getfield(L, 1, "datafile")  == LUA_TSTRING) { datafile  = lua_tostring (L, -1);                 } lua_pop(L, 1);
        if (lua_getfield(L, 1, "data")      == LUA_TSTRING) { data      = lua_tolstring(L, -1, &datasize);      } lua_pop(L, 1);
        if (lua_getfield(L, 1, "signature") == LUA_TSTRING) { signature = lua_tolstring(L, -1, &signaturesize); } lua_pop(L, 1);
        if (lua_getfield(L, 1, "password")  == LUA_TSTRING) { password  = lua_tostring (L, -1);                 } lua_pop(L, 1);
        if (certfile && password && (data || datafile)) {
            int okay = -1;
            PKCS7 *p7 = NULL; 
            BIO *input = NULL; 
            BIO *certificate = NULL;
            X509 *x509 = NULL;
         // OPENSSL_STACK stack = NULL;
            int flags = PKCS7_NOVERIFY | PKCS7_BINARY;
            certificate = openssllib_state.BIO_new_file(certfile, "rb");
            if (! certificate) {
                message = m_invalid_certificate_file;
                goto DONE;
            }
            x509 = openssllib_state.PEM_read_bio_X509(certificate, NULL, NULL, password);
            if (! x509) {
                message = m_invalid_certificate;
                goto DONE;
            }
         // stack = openssllib_state.OPENSSL_sk_new_null();
         // if (! stack) { 
         //     message = m_invalid_certificate;
         //     goto DONE;
         // }
         // openssllib_state.OPENSSL_sk_push(stack, x509);
            if (! openssllib_state.d2i_PKCS7(&p7, &signature, (long) signaturesize)) {
                message = m_invalid_signature;
                goto DONE;
            }
            if (datafile) { 
                input = openssllib_state.BIO_new_file(datafile, "rb");
            } else {
                input = openssllib_state.BIO_new_mem_buf(data, (int) datasize);
            }
            if (! input) {
                message = m_invalid_data_file;
                goto DONE;
            }
//            okay = openssllib_state.PKCS7_verify(p7, stack, NULL, input, NULL, flags);
            okay = openssllib_state.PKCS7_verify(p7, NULL, NULL, input, NULL, flags);
          DONE:
            if (certificate) { openssllib_state.BIO_free(certificate);  }
            if (x509)        { openssllib_state.X509_free(x509);        }
            if (p7)          { openssllib_state.PKCS7_free(p7);         }
            if (input)       { openssllib_state.BIO_free(input);        }
         // if (stack)       { openssllib_state.OPENSSL_sk_free(stack); }
            if (okay > 0) {
                lua_pushboolean(L, okay);
                return 1;
            } else { 
                message = m_invalid_signature;
            }
        }
    }
    lua_pushboolean(L, 0);
    if (message) { 
        lua_pushinteger(L, message);
        return 2;
    } else { 
        return 1;
    }
    return 1;
}

static int openssllib_getversion(lua_State * L)
{
    if (openssllib_state.initialized) {
        /* todo, if ever */
        lua_pushinteger(L, 1);
    } else { 
        lua_pushinteger(L, 0);
    }
    return 1;
}

static struct luaL_Reg openssllib_function_list[] = {
    { "initialize", openssllib_initialize },
    { "sign",       openssllib_sign       },
    { "verify",     openssllib_verify     },
    { "getversion", openssllib_getversion },
    { NULL,         NULL                  },
};

int luaopen_openssl(lua_State * L)
{
    lmt_library_register(L, "openssl", openssllib_function_list);
    return 0;
}
