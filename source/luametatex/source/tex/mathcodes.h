/*
    See license.txt in the root of this project.
*/

# ifndef MATHCODES_H
# define MATHCODES_H

/*tex this is a flag for |scan_delimiter| */

# define no_mathcode        0
# define tex_mathcode       8
# define umath_mathcode    21
# define umathnum_mathcode 22

# if 1

    typedef struct mathcodeval {
        int character_value:32;
        int class_value:8;
        int family_value:8;
    } mathcodeval;

# else

    typedef struct mathcodeval {
        int class_value;
        int family_value;
        int character_value;
    } mathcodeval;

# endif

void set_math_code(int n, int mathclass, int mathfamily, int mathcharacter, quarterword gl);

mathcodeval get_math_code(int n);
int get_math_code_num(int n);
int get_del_code_num(int n);
mathcodeval scan_mathchar(int extcode);
mathcodeval scan_delimiter_as_mathchar(int extcode);

mathcodeval mathchar_from_integer(int value, int extcode);
void show_mathcode_value(mathcodeval d);
void show_mathcode_value_old(int value);

# if 1

    typedef struct delcodeval {
        int small_character_value:32;
        int large_character_value:32;
        int class_value:8;
        int small_family_value:8;
        int large_family_value:8;
    } delcodeval;

# else

    typedef struct delcodeval {
        int class_value;
        int small_family_value;
        int small_character_value;
        int large_family_value;
        int large_character_value;
    } delcodeval;

# endif

void set_del_code(int n, int smathfamily, int smathcharacter, int lmathfamily, int lmathcharacter, quarterword gl);

delcodeval get_del_code(int n);

void unsave_math_codes(quarterword grouplevel);
void initialize_math_codes(void);
void dump_math_codes(void);
void undump_math_codes(void);

# endif
