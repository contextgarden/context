/*
    See license.txt in the root of this project.
*/

# ifndef LMT_LLUALIB_H
# define LMT_LLUALIB_H

/*tex

    We started with multiple instances but that made no sense as dealing with isolated instances
    and talking to \TEX\ also means that one then has to have a channel between instances. and it's
    not worth the trouble. So we went for one instance.

    This also means that the names related to directlua instances have been removed in the follow
    up.

*/

extern void lmt_dump_registers       (dumpstream f);
extern void lmt_undump_registers     (dumpstream f);
extern void lmt_bytecode_call        (int slot);

extern void lmt_initialize_functions (int set_size);

# endif
