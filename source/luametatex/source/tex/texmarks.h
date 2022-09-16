/*
    See license.txt in the root of this project.
*/

# ifndef LMT_MARKS_H
# define LMT_MARKS_H

typedef enum get_mark_codes {
    current_marks_code,
    top_marks_code,
    first_marks_code,
    bot_marks_code,
    split_first_marks_code,
    split_bot_marks_code,
    /* these map to zero */
    top_mark_code,         /*tex the mark in effect at the previous page break */
    first_mark_code,       /*tex the first mark between |top_mark| and |bot_mark| */
    bot_mark_code,         /*tex the mark in effect at the current page break */
    split_first_mark_code, /*tex the first mark found by |\vsplit| */
    split_bot_mark_code,   /*tex the last mark found by |\vsplit| */
} get_mark_codes;

# define first_valid_mark_code top_marks_code
# define last_unique_mark_code split_bot_marks_code
# define last_get_mark_code    split_bot_mark_code

typedef enum set_mark_codes {
    set_mark_code,
    set_marks_code,
    clear_marks_code,
    flush_marks_code,
} set_mark_codes;

# define last_set_mark_code flush_marks_code

typedef halfword mark_record[split_bot_marks_code+1];

typedef struct mark_state_info {
    mark_record *data;
    int          min_used;
    int          max_used;
    memory_data  mark_data;
} mark_state_info;

extern mark_state_info lmt_mark_state;

extern void     tex_initialize_marks          (void);
extern int      tex_valid_mark                (halfword m);
extern void     tex_reset_mark                (halfword m);
extern void     tex_wipe_mark                 (halfword m);
extern void     tex_delete_mark               (halfword m, int what);
extern halfword tex_get_some_mark             (halfword chr, halfword val);
extern halfword tex_new_mark                  (quarterword subtype, halfword cls, halfword ptr);
extern void     tex_update_top_marks          (void);
extern void     tex_update_first_and_bot_mark (halfword m);
extern void     tex_update_first_marks        (void);
extern void     tex_update_split_mark         (halfword m);
extern void     tex_show_marks                (void);
extern int      tex_has_mark                  (halfword m);
extern halfword tex_get_mark                  (halfword m, halfword s);
extern void     tex_set_mark                  (halfword m, halfword s, halfword v);

extern void     tex_run_mark                  (void);

# endif
