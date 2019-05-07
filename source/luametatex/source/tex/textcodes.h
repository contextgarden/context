/*
    See license.txt in the root of this project.
*/

# ifndef TEXTCODES_H
# define TEXTCODES_H

void set_cat_code(int h, int n, halfword v, quarterword gl);
halfword get_cat_code(int h, int n);
int valid_catcode_table(int h);
void unsave_cat_codes(int h, quarterword gl);
void copy_cat_codes(int from, int to);
void initex_cat_codes(int h);

void set_lc_code(int n, halfword v, quarterword gl);
halfword get_lc_code(int n);

void set_uc_code(int n, halfword v, quarterword gl);
halfword get_uc_code(int n);

void set_sf_code(int n, halfword v, quarterword gl);
halfword get_sf_code(int n);

void set_hj_code(int l, int n, halfword v, quarterword gl);
halfword get_hj_code(int l, int n);
void hj_codes_from_lc_codes(int h);

void initialize_text_codes(void);
void unsave_text_codes(quarterword grouplevel);

void dump_text_codes(void);
void undump_text_codes(void);

void free_math_codes(void);
void free_text_codes(void);

# endif
