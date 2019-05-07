/*
    See license.txt in the root of this project.
*/

# ifndef ALIGN_H
# define ALIGN_H 1

/*tex

    We enter |\span| into |eqtb| with |tab_mark| as its command code, and with
    |span_code| as the command modifier. This makes \TEX\ interpret it
    essentially the same as an alignment delimiter like |&|, yet it is
    recognizably different when we need to distinguish it from a normal
    delimiter. It also turns out to be useful to give a special |cr_code| to
    |\cr|, and an even larger |cr_cr_code| to |\crcr|.

    The end of a template is represented by two frozen control sequences called
    |\endtemplate|. The first has the command code |end_template|, which is
    |>outer_call|, so it will not easily disappear in the presence of errors. The
    |get_x_token| routine converts the first into the second, which has |endv| as
    its command code.

*/

# define tab_mark_cmd_code 1114113       /*tex |biggest_char+2| */
# define span_code         1114114       /*tex |biggest_char+3| */
# define cr_code           (span_code+1) /*tex distinct from |span_code| and from any character */
# define cr_cr_code        (cr_code  +1) /*tex this distinguishes |\crcr| from |\cr| */

extern void init_align(void);
extern void initialize_alignments(void);

extern int fin_col(void);
extern void fin_row(void);

extern void align_peek(void);
extern void insert_vj_template(void);

# endif
