/*
    See license.txt in the root of this project.
*/

# ifndef EXPAND_H
# define EXPAND_H

typedef struct expand_state_info {
    int is_in_csname;
    int long_state;
    halfword pstack[9];
    int expand_depth_count;
} expand_state_info ;

extern expand_state_info expand_state ;

extern void expand(void);
extern void complain_missing_csname(void);
extern void get_x_token(void);
extern void x_token(void);

# define clear_marks_code      1
# define biggest_mark      65535

# define top_mark_code         0 /*tex the mark in effect at the previous page break */
# define first_mark_code       1 /*tex the first mark between |top_mark| and |bot_mark| */
# define bot_mark_code         2 /*tex the mark in effect at the current page break */
# define split_first_mark_code 3 /*tex the first mark found by |\vsplit| */
# define split_bot_mark_code   4 /*tex the last mark found by |\vsplit| */
# define marks_code            5

typedef struct mark_state_info {
    halfword top_marks_array[(biggest_mark + 1)];
    halfword first_marks_array[(biggest_mark + 1)];
    halfword bot_marks_array[(biggest_mark + 1)];
    halfword split_first_marks_array[(biggest_mark + 1)];
    halfword split_bot_marks_array[(biggest_mark + 1)];
    halfword biggest_used_mark;
} mark_state_info;

extern mark_state_info mark_state ;

# define top_marks_array         mark_state.top_marks_array
# define first_marks_array       mark_state.first_marks_array
# define bot_marks_array         mark_state.bot_marks_array
# define split_first_marks_array mark_state.split_first_marks_array
# define split_bot_marks_array   mark_state.split_bot_marks_array
# define biggest_used_mark       mark_state.biggest_used_mark

# define top_mark(A) top_marks_array[(A)]
# define first_mark(A) first_marks_array[(A)]
# define bot_mark(A) bot_marks_array[(A)]
# define split_first_mark(A) split_first_marks_array[(A)]
# define split_bot_mark(A) split_bot_marks_array[(A)]

# define set_top_mark(A,B) top_mark(A)=(B)
# define set_first_mark(A,B) first_mark(A)=(B)
# define set_bot_mark(A,B) bot_mark(A)=(B)
# define set_split_first_mark(A,B) split_first_mark(A)=(B)
# define set_split_bot_mark(A,B) split_bot_mark(A)=(B)

# define delete_top_mark(A) do { \
    if (top_mark(A)!=null) \
        delete_token_ref(top_mark(A)); \
    top_mark(A)=null; \
} while (0)

# define delete_bot_mark(A) do { \
    if (bot_mark(A)!=null) \
        delete_token_ref(bot_mark(A)); \
    bot_mark(A)=null; \
} while (0)

# define delete_first_mark(A) do { \
    if (first_mark(A)!=null) \
        delete_token_ref(first_mark(A)); \
    first_mark(A)=null; \
} while (0)

# define delete_split_first_mark(A) do { \
    if (split_first_mark(A)!=null) \
        delete_token_ref(split_first_mark(A)); \
    split_first_mark(A)=null; \
} while (0)

# define delete_split_bot_mark(A) do { \
    if (split_bot_mark(A)!=null) \
        delete_token_ref(split_bot_mark(A)); \
    split_bot_mark(A)=null; \
} while (0)

extern void initialize_marks(void);

# endif
