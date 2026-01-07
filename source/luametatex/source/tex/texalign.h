/*
    See license.txt in the root of this project.
*/

# ifndef LMT_ALIGN_H
# define LMT_ALIGN_H

/* todo : rename */

extern void     tex_initialize_alignments        (void);
extern void     tex_cleanup_alignments           (void);

extern void     tex_insert_alignment_template    (void);
extern void     tex_run_alignment_initialize     (void);
extern void     tex_run_alignment_end_template   (void);
extern void     tex_run_alignment_error          (void);

extern void     tex_finish_alignment_group       (void);
extern void     tex_finish_no_alignment_group    (void);

extern void     tex_alignment_interwoven_error   (int n);
extern halfword tex_alignment_hold_token_head    (void);

extern int      tex_in_alignment                 (void);

extern int      tex_show_alignment_record        (void);

extern halfword tex_alignment_row_number         (void);
extern halfword tex_alignment_column_number      (void);
extern halfword tex_alignment_last_row_number    (void);
extern halfword tex_alignment_last_column_number (void);
extern scaled   tex_alignment_tabskip_amount     (void);

extern void     tex_alignment_scan_options       (void);
extern void     tex_alignment_set_options        (halfword options);
extern halfword tex_alignment_get_options        (void);

# endif
