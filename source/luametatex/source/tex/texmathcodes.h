/*
    See license.txt in the root of this project.
*/

# ifndef LMT_MATHCODES_H
# define LMT_MATHCODES_H

/*tex
    We keep this special value which is used in |0x8000| so we have no real problem with 8 being
    some other class as well. The 8 here is not really a class.
*/

# define active_math_class_value 8

typedef enum mathcode_codes {
    no_mathcode,
    tex_mathcode,
    umath_mathcode,
 /* umathnum_mathcode, */
    mathspec_mathcode
} mathcode_codes;

typedef struct mathcodeval {
    short class_value;
    short family_value;
    int   character_value;
} mathcodeval;

typedef struct mathdictval {
    unsigned short properties; // 1=char 2=open 4=close 8=middle 16=middle==class 
    unsigned short group;
    unsigned int   index;
} mathdictval;

# undef small /* defined in some microsoft library */

/*tex
    Until we drop 8 bit font support we keep the small and large distinction but it might
    go away some day as it wastes memory.
*/

typedef struct delcodeval {
    mathcodeval small;
    mathcodeval large;
} delcodeval;

typedef struct mathspecval {
    mathcodeval code;
    mathdictval dict;
} mathspecval;

extern void        tex_set_math_code              (int n, mathcodeval v, int gl);
extern mathcodeval tex_get_math_code              (int n);
extern int         tex_get_math_code_number       (int n);
extern mathcodeval tex_no_math_code               (void);

extern void        tex_set_del_code               (int n, delcodeval v, int gl);
extern delcodeval  tex_get_del_code               (int n);
extern int         tex_get_del_code_number        (int n);
extern int         tex_has_del_code               (delcodeval v);
extern delcodeval  tex_no_del_code                (void);

extern mathcodeval tex_scan_mathchar              (int extcode);
extern mathdictval tex_scan_mathdict              (void);
extern mathcodeval tex_scan_delimiter_as_mathchar (int extcode);
extern mathcodeval tex_mathchar_from_integer      (int value, int extcode);
extern mathcodeval tex_mathchar_from_spec         (int value);

extern void        tex_show_mathcode_value        (mathcodeval d, int extcode);
extern void        tex_unsave_math_codes          (int grouplevel);
extern void        tex_initialize_math_codes      (void);
extern void        tex_dump_math_codes            (dumpstream f);
extern void        tex_undump_math_codes          (dumpstream f);

extern void        tex_free_math_codes            (void);

extern mathdictval tex_no_dict_code               (void);

# endif
