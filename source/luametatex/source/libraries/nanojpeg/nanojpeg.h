/* 
    See nanojpeg.c for author, copyright, api, etc. details or check out:

    https://keyj.emphy.de/nanojpeg/

*/

# ifndef _NANOJPEG_H
# define _NANOJPEG_H

typedef enum _nj_result {
    NJ_OK,
    NJ_NO_JPEG,
    NJ_UNSUPPORTED,
    NJ_OUT_OF_MEM,
    NJ_INTERNAL_ERR,
    NJ_SYNTAX_ERROR,
  __NJ_FINISHED,
} nj_result_t;

void            njInit         (void);
nj_result_t     njDecode       (const void* jpeg, const int size);
int             njGetWidth     (void);
int             njGetHeight    (void);
int             njIsColor      (void);
unsigned char * njGetImage     (void);
int             njGetImageSize (void);
void            njDone         (void);

# endif 
