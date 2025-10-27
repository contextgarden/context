/*
    See license.txt in the root of this project.
*/

# ifndef LMT_SPECIFICAITONS_H
# define LMT_SPECIFICAITONS_H

typedef enum specification_option_flags {
    specification_option_repeat   = 0x0001,
    specification_option_double   = 0x0002,
    specification_option_largest  = 0x0004, /* of widow or club */
    specification_option_presets  = 0x0008, /* definition includes first and second pass */
    specification_option_integer  = 0x0010, /* integer first */
    specification_option_final    = 0x0020, /* single value replacement, so no repeat */
    specification_option_default  = 0x0040, /* all default */
    specification_option_ignore   = 0x0080, /* not yet: ignore a slot in shape */
    specification_option_rotate   = 0x0100, /* when |index| exceeds |count| we use |index % count + 1| instead */
    specification_option_constant = 0x0200,
} specifications_options_flags;

# define specification_index(a,n) ((memoryword *) specification_pointer(a))[n - 1]

# define specification_repeat(a)   ((specification_options(a) & specification_option_repeat)   == specification_option_repeat)
# define specification_double(a)   ((specification_options(a) & specification_option_double)   == specification_option_double)
# define specification_largest(a)  ((specification_options(a) & specification_option_largest)  == specification_option_largest)
# define specification_presets(a)  ((specification_options(a) & specification_option_presets)  == specification_option_presets)
# define specification_integer(a)  ((specification_options(a) & specification_option_integer)  == specification_option_integer)
# define specification_final(a)    ((specification_options(a) & specification_option_final)    == specification_option_final)
# define specification_default(a)  ((specification_options(a) & specification_option_default)  == specification_option_default)
# define specification_ignore(a)   ((specification_options(a) & specification_option_ignore)   == specification_option_ignore)
# define specification_rotate(a)   ((specification_options(a) & specification_option_rotate)   == specification_option_rotate)
# define specification_constant(a) ((specification_options(a) & specification_option_constant) == specification_option_constant)

/* bad names, same as enum */

# define specification_option_double(o)   ((o & specification_option_double)   == specification_option_double)
# define specification_option_integer(o)  ((o & specification_option_integer)  == specification_option_integer)
# define specification_option_final(o)    ((o & specification_option_final)    == specification_option_final)  
# define specification_option_default(o)  ((o & specification_option_default)  == specification_option_default)  
# define specification_option_ignore(o)   ((o & specification_option_ignore)   == specification_option_ignore)  
# define specification_option_rotate(o)   ((o & specification_option_rotate)   == specification_option_rotate)  
# define specification_option_constant(o) ((o & specification_option_constant) == specification_option_constant)  

# define specification_n(a,n) (specification_repeat(a) ? ((n - 1) % specification_count(a) + 1) : (n > specification_count(a) ? specification_count(a) : n))

/* interesting: 1Kb smaller bin: */

// static inline halfword specification_n(halfword a, halfword n) { return specification_repeat(a) ? ((n - 1) % specification_count(a) + 1) : (n > specification_count(a) ? specification_count(a) : n); }

# define par_passes_size     20
# define balance_shape_size   5
# define balance_passes_size  9

# define par_passes_slot(n,m)     ((n-1)*par_passes_size+m)
# define balance_shape_slot(n,m)  ((n-1)*balance_shape_size+m)
# define balance_passes_slot(n,m) ((n-1)*balance_passes_size+m)

extern void            tex_null_specification_list     (halfword a);
extern void            tex_new_specification_list      (halfword a, halfword n);
extern void            tex_dispose_specification_list  (halfword a);
extern void            tex_copy_specification_list     (halfword a, halfword b);
extern void            tex_shift_specification_list    (halfword a, int n, int rotate);

static inline int      tex_get_specification_count     (halfword a)                         { return a ? specification_count(a) : 0; }
static inline void     tex_set_specification_option    (halfword a, int o)                  { specification_options(a) |= o; }
static inline int      tex_has_specification_option    (halfword a, int o)                  { return (specification_options(a) & o) == o; }

static inline void     tex_add_specification_option    (halfword a, halfword o)             { specification_options(a) |= o; }
static inline void     tex_remove_specification_option (halfword a, halfword o)             { specification_options(a) &= ~o; }

static inline int      tex_get_specification_decent    (halfword a)                         { return specification_anything_1(a); }
static inline void     tex_set_specification_decent    (halfword a, int d)                  { specification_anything_1(a) = d; }

static inline halfword tex_get_specification_indent    (halfword a, halfword n)             { return specification_index(a,specification_n(a,n)).half0; }
static inline void     tex_set_specification_indent    (halfword a, halfword n, halfword v) { specification_index(a,n).half0 = v; }

static inline halfword tex_get_specification_width     (halfword a, halfword n)             { return specification_index(a,specification_n(a,n)).half1; }
static inline void     tex_set_specification_width     (halfword a, halfword n, halfword v) { specification_index(a,n).half1 = v; }

/*tex
    because we want to be able to map the singular penalties efficiently by using the two extra 
    fields that we have anyway, we have special accessors for the penalties. 
*/

/* I'll make a specification module instead. */

static inline halfword tex_get_specification_penalty(halfword a, halfword n)        
{ 
    if (n <= 0 || ! a || ! specification_count(a)) {
        return 0;
    } else if (n > specification_count(a)) {
        if (specification_final(a)) { 
            return 0;
        } else {
            n = specification_count(a);
        }
    }
    if (specification_pointer(a)) {
        return specification_index(a,specification_n(a,n)).half0; 
    } else if (n == 1) {
        return specification_anything_1(a);
    } else { 
        return 0;
    }
}

static inline halfword tex_get_specification_nepalty(halfword a, halfword n)             
{ 
    if (n <= 0 || ! a || ! specification_count(a)) {
        return 0;
    } else if (n > specification_count(a)) {
        if (specification_final(a)) { 
            return 0;
        } else {
            n = specification_count(a);
        }
    }
    if (specification_pointer(a)) {
        return specification_index(a,specification_n(a,n)).half1; 
    } else if (n == 1) {
        return specification_anything_2(a);
    } else { 
        return 0;
    }
}

static inline void tex_set_specification_penalty(halfword a, halfword n, halfword v) { 
    if (specification_pointer(a)) {
        specification_index(a,n).half0 = v; 
    } else { 
        specification_anything_1(a) = v;
    }
}

static inline void tex_set_specification_nepalty(halfword a, halfword n, halfword v) { 
    if (specification_pointer(a)) {
        specification_index(a,n).half1 = v; 
    } else { 
        specification_anything_2(a) = v;
    }
}

/* Here come the slot ones: */

static inline halfword tex_get_specification_fitness_class(halfword a, halfword n) 
{ 
    return specification_index(a,n).half0; 
}

static inline void tex_set_specification_fitness_class(halfword a, halfword n, halfword v) 
{ 
    specification_index(a,n).half0 = v; 
}

# define specification_adjacent_max specification_anything_1
# define specification_adjacent_adj specification_anything_2

static inline halfword tex_get_specification_adjacent_d(halfword a, halfword n)             
{ 
    if (n <= 0 || ! a || ! specification_count(a)) {
        return 0;
    } else if (specification_size(a)) { 
        return specification_index(a,specification_n(a,n)).half0; 
    } else {
        return n > 1 ? specification_adjacent_adj(a) : 0;
    }
}

static inline halfword tex_get_specification_adjacent_u(halfword a, halfword n)
{ 
    if (n <= 0 || ! a || ! specification_count(a)) {
        return 0;
    } else if (specification_size(a)) { 
        return specification_index(a,specification_n(a,n)).half1; 
    } else { 
        return n > 1 ? specification_adjacent_adj(a) : 0;
    }
}

static inline void tex_set_specification_adjacent_d(halfword a, halfword n, halfword v) 
{ 
    if (specification_size(a)) { 
        specification_index(a,specification_n(a,n)).half0 = v; 
    } else { 
        specification_adjacent_adj(a) = v;
    }
}

static inline void tex_set_specification_adjacent_u(halfword a, halfword n, halfword v) 
{ 
    if (specification_size(a)) { 
        specification_index(a,specification_n(a,n)).half1 = v; 
    } else { 
        specification_adjacent_adj(a) = v;
    }
}

typedef enum passes_features { 
    /* */
    passes_quit_pass            = 0x0001,
    passes_skip_pass            = 0x0002,
    passes_callback_set         = 0x0004,
    passes_criterium_set        = 0x0008,
    /* */
    passes_if_adjust_spacing    = 0x0010,
    passes_if_emergency_stretch = 0x0020,
    passes_if_text              = 0x0040,
    passes_if_glue              = 0x0080,
    passes_if_space_factor      = 0x0100,
    passes_if_math              = 0x0200,
    passes_unless_math          = 0x0400,
    passes_if_looseness         = 0x0800,
    passes_test_set             = passes_if_adjust_spacing
                                | passes_if_emergency_stretch
                                | passes_if_text             
                                | passes_if_glue             
                                | passes_if_space_factor
                                | passes_if_math             
                                | passes_unless_math         
                                | passes_if_looseness,         
    /* */
} passes_features;

/*tex 
    As a step up to more granular fitness we had nine classes and therefore a nine bit class 
    vector:

    \starttyping
    typedef enum passes_classes { 
        very_loose_fit_class   = 0x0001,
        loose_fit_class        = 0x0002,     
        almost_loose_fit_class = 0x0004,
        barely_loose_fit_class = 0x0008,    
        decent_fit_class       = 0x0010,    
        barely_tight_fit_class = 0x0020,
        almost_tight_fit_class = 0x0040,     
        tight_fit_class        = 0x0080,     
        very_tight_fit_class   = 0x0100,     
    } passes_classes;
    \stoptyping

    We no longer use these names but keep it here as a possible naming scheme (one that we 
    actually use in \CONTEXT). 

*/

# define passes_first_final specification_anything_1
# define passes_identifier  specification_anything_2

typedef enum passes_parameter_okay { 
    passes_hyphenation_okay          = 0x00000001,
    passes_emergencyfactor_okay      = 0x00000002,
    passes_emergencypercentage_okay  = 0x00000004,
    passes_emergencywidthextra_okay  = 0x00000008,
    passes_emergencyleftextra_okay   = 0x00000010,
    passes_emergencyrightextra_okay  = 0x00000020,
    /* */
    passes_emergencystretch_okay     = 0x00000040,
    /* */
    passes_adjustspacingstep_okay    = 0x00000080,
    passes_adjustspacingstretch_okay = 0x00000100,
    passes_adjustspacingshrink_okay  = 0x00000200,
    passes_adjustspacing_okay        = 0x00000400,
    /* */
    passes_linepenalty_okay          = 0x00000800,
    passes_toddlerpenalties_okay     = 0x00001000,
    passes_orphanpenalty_okay        = 0x00002000,
    passes_lefttwindemerits_okay     = 0x00004000,
    passes_righttwindemerits_okay    = 0x00008000,
    passes_extrahyphenpenalty_okay   = 0x00010000,
    passes_doublehyphendemerits_okay = 0x00020000,
    passes_finalhyphendemerits_okay  = 0x00040000,
    passes_adjdemerits_okay          = 0x00080000, /*tex common */
    passes_adjacentdemerits_okay     = 0x00080000, /*tex common */
    passes_orphanpenalties_okay      = 0x00100000,
    passes_orphanlinefactors_okay    = 0x00200000,
    passes_fitnessclasses_okay       = 0x00400000,
    passes_linebreakchecks_okay      = 0x00800000,
    passes_linebreakoptional_okay    = 0x01000000,
    passes_sffactor_okay             = 0x02000000, 
    passes_sfstretchfactor_okay      = 0x04000000, 
    /* */
    passes_callback_okay             = 0x08000000,
    /* */
    passes_mathpenaltyfactor_okay    = 0x10000000,
    /* */
    passes_looseness_okay            = 0x20000000,
    /* */
    passes_reserved_1_okay           = 0x40000000,
    passes_reserved_2_okay           = 0x80000000,
    /* nicer */
    passes_balancepenalty_okay       = 0x00000800,
    passes_balancechecks_okay        = 0x00800000,
    /*tex Watch out: the following options exceed halfword: |noad_options| are |long long|. */
} passes_parameters_okay;

/*tex The Microsoft compiler truncates to int, so: */

# define passes_threshold_okay     (uint64_t) 0x0000000100000000
# define passes_demerits_okay      (uint64_t) 0x0000000200000000
# define passes_tolerance_okay     (uint64_t) 0x0000000400000000
# define passes_classes_okay       (uint64_t) 0x0000000800000000
# define passes_emergencyunit_okay (uint64_t) 0x0000001000000000

static const uint64_t passes_basics_okay = 
    passes_hyphenation_okay 
  | passes_emergencyfactor_okay
  | passes_emergencypercentage_okay
  | passes_emergencywidthextra_okay
  | passes_emergencyleftextra_okay
  | passes_emergencyrightextra_okay
  | passes_emergencyunit_okay;

static const uint64_t passes_expansion_okay = 
    passes_adjustspacingstep_okay 
  | passes_adjustspacingstretch_okay
  | passes_adjustspacingshrink_okay
  | passes_adjustspacing_okay;

static const uint64_t passes_additional_okay = 
    passes_linepenalty_okay
  | passes_toddlerpenalties_okay
  | passes_orphanpenalty_okay
  | passes_lefttwindemerits_okay
  | passes_righttwindemerits_okay
  | passes_extrahyphenpenalty_okay
  | passes_doublehyphendemerits_okay
  | passes_finalhyphendemerits_okay
  | passes_adjdemerits_okay
  | passes_adjacentdemerits_okay
  | passes_orphanpenalties_okay
  | passes_orphanlinefactors_okay
  | passes_fitnessclasses_okay
  | passes_linebreakchecks_okay
  | passes_linebreakoptional_okay
  | passes_sffactor_okay
  | passes_sfstretchfactor_okay;

static inline void     tex_set_passes_okay                 (halfword a, halfword n, uint64_t v) { specification_index(a,par_passes_slot(n, 1)).long0   |= v; }
static inline void     tex_set_passes_features             (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 2)).quart00 |= (v & 0xFFFF); }
static inline void     tex_set_passes_classes              (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 2)).quart01 |= (v & 0xFFFF); }
static inline void     tex_set_passes_threshold            (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 2)).half1    = v; }
static inline void     tex_set_passes_demerits             (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 3)).half0    = v; }
static inline void     tex_set_passes_tolerance            (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 3)).half1    = v; }
static inline void     tex_set_passes_hyphenation          (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 4)).half0    = v; }
static inline void     tex_set_passes_emergencyfactor      (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 4)).half1    = v; }
static inline void     tex_set_passes_mathpenaltyfactor    (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 5)).half0    = v; }
static inline void     tex_set_passes_extrahyphenpenalty   (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 5)).half1    = v; }
static inline void     tex_set_passes_doublehyphendemerits (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 6)).half0    = v; }
static inline void     tex_set_passes_finalhyphendemerits  (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 6)).half1    = v; }
static inline void     tex_set_passes_adjdemerits          (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 7)).half0    = v; }
static inline void     tex_set_passes_linepenalty          (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 7)).half1    = v; }
static inline void     tex_set_passes_adjustspacingstep    (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 8)).half0    = v; }
static inline void     tex_set_passes_adjustspacingshrink  (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 8)).half1    = v; }
static inline void     tex_set_passes_adjustspacingstretch (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 9)).half0    = v; }
static inline void     tex_set_passes_adjustspacing        (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n, 9)).half1    = v; }
static inline void     tex_set_passes_emergencypercentage  (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,10)).half0    = v; }
static inline void     tex_set_passes_linebreakoptional    (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,10)).half1    = v; }
static inline void     tex_set_passes_callback             (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,11)).half0    = v; }
static inline void     tex_set_passes_orphanpenalty        (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,11)).half1    = v; }
static inline void     tex_set_passes_fitnessclasses       (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,12)).half0    = v; }
static inline void     tex_set_passes_adjacentdemerits     (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,12)).half1    = v; }
static inline void     tex_set_passes_toddlerpenalties     (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,13)).half0    = v; }
static inline void     tex_set_passes_linebreakchecks      (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,13)).half1    = v; }
static inline void     tex_set_passes_lefttwindemerits     (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,14)).half0    = v; }
static inline void     tex_set_passes_righttwindemerits    (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,14)).half1    = v; }
static inline void     tex_set_passes_emergencystretch     (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,15)).half0    = v; }
static inline void     tex_set_passes_emergencyleftextra   (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,15)).half1    = v; }
static inline void     tex_set_passes_emergencyrightextra  (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,16)).half0    = v; }
static inline void     tex_set_passes_emergencywidthextra  (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,16)).half1    = v; }
static inline void     tex_set_passes_sffactor             (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,17)).half0    = v; }
static inline void     tex_set_passes_sfstretchfactor      (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,17)).half1    = v; }
static inline void     tex_set_passes_looseness            (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,18)).half0    = v; }
static inline void     tex_set_passes_orphanlinefactors    (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,18)).half1    = v; }
static inline void     tex_set_passes_orphanpenalties      (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,19)).half0    = v; }
static inline void     tex_set_passes_emergencyunit        (halfword a, halfword n, halfword v) { specification_index(a,par_passes_slot(n,19)).half1    = v; }

static inline uint64_t tex_get_passes_okay                 (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 1)).long0;   }
static inline halfword tex_get_passes_features             (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 2)).quart00; }
static inline halfword tex_get_passes_classes              (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 2)).quart01; }
static inline halfword tex_get_passes_threshold            (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 2)).half1;   }
static inline halfword tex_get_passes_demerits             (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 3)).half0;   }
static inline halfword tex_get_passes_tolerance            (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 3)).half1;   }
static inline halfword tex_get_passes_hyphenation          (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 4)).half0;   }
static inline halfword tex_get_passes_emergencyfactor      (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 4)).half1;   }
static inline halfword tex_get_passes_mathpenaltyfactor    (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 5)).half0;   }
static inline halfword tex_get_passes_extrahyphenpenalty   (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 5)).half1;   }
static inline halfword tex_get_passes_doublehyphendemerits (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 6)).half0;   }
static inline halfword tex_get_passes_finalhyphendemerits  (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 6)).half1;   }
static inline halfword tex_get_passes_adjdemerits          (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 7)).half0;   }
static inline halfword tex_get_passes_linepenalty          (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 7)).half1;   }
static inline halfword tex_get_passes_adjustspacingstep    (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 8)).half0;   }
static inline halfword tex_get_passes_adjustspacingshrink  (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 8)).half1;   }
static inline halfword tex_get_passes_adjustspacingstretch (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 9)).half0;   }
static inline halfword tex_get_passes_adjustspacing        (halfword a, halfword n) { return specification_index(a,par_passes_slot(n, 9)).half1;   }
static inline halfword tex_get_passes_emergencypercentage  (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,10)).half0;   }
static inline halfword tex_get_passes_linebreakoptional    (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,10)).half1;   }
static inline halfword tex_get_passes_callback             (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,11)).half0;   }
static inline halfword tex_get_passes_orphanpenalty        (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,11)).half1;   }
static inline halfword tex_get_passes_fitnessclasses       (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,12)).half0;   }
static inline halfword tex_get_passes_adjacentdemerits     (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,12)).half1;   }
static inline halfword tex_get_passes_toddlerpenalties     (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,13)).half0;   }
static inline halfword tex_get_passes_linebreakchecks      (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,13)).half1;   }
static inline halfword tex_get_passes_lefttwindemerits     (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,14)).half0;   }
static inline halfword tex_get_passes_righttwindemerits    (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,14)).half1;   }
static inline halfword tex_get_passes_emergencystretch     (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,15)).half0;   }
static inline halfword tex_get_passes_emergencyleftextra   (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,15)).half1;   }
static inline halfword tex_get_passes_emergencyrightextra  (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,16)).half0;   }
static inline halfword tex_get_passes_emergencywidthextra  (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,16)).half1;   }
static inline halfword tex_get_passes_sffactor             (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,17)).half0;   }
static inline halfword tex_get_passes_sfstretchfactor      (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,17)).half1;   }
static inline halfword tex_get_passes_looseness            (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,18)).half0;   }
static inline halfword tex_get_passes_orphanlinefactors    (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,18)).half1;   }
static inline halfword tex_get_passes_orphanpenalties      (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,19)).half0;   }
static inline halfword tex_get_passes_emergencyunit        (halfword a, halfword n) { return specification_index(a,par_passes_slot(n,19)).half1;   }

/* balance shape */

typedef enum balance_step_options {
    balance_step_option_top    = 0x0001,
    balance_step_option_bottom = 0x0002,
} balance_step_options;

# define balance_shape_identifier  specification_anything_2

static inline void     tex_set_balance_index         (halfword a, halfword n, halfword v) { specification_index(a,balance_shape_slot(n,1)).half0 = v; }
static inline void     tex_set_balance_vsize         (halfword a, halfword n, halfword v) { specification_index(a,balance_shape_slot(n,1)).half1 = v; }
static inline void     tex_set_balance_topskip       (halfword a, halfword n, halfword v) { specification_index(a,balance_shape_slot(n,2)).half0 = v; }
static inline void     tex_set_balance_bottomskip    (halfword a, halfword n, halfword v) { specification_index(a,balance_shape_slot(n,2)).half1 = v; }
static inline void     tex_set_balance_options       (halfword a, halfword n, halfword v) { specification_index(a,balance_shape_slot(n,3)).half0 = v; }
static inline void     tex_set_balance_extra         (halfword a, halfword n, halfword v) { specification_index(a,balance_shape_slot(n,3)).half1 = v; }
static inline void     tex_set_balance_topdiscard    (halfword a, halfword n, halfword v) { specification_index(a,balance_shape_slot(n,4)).half0 = v; }
static inline void     tex_set_balance_bottomdiscard (halfword a, halfword n, halfword v) { specification_index(a,balance_shape_slot(n,4)).half1 = v; }

static inline halfword tex_get_balance_index         (halfword a, halfword n) { return specification_index(a,balance_shape_slot(specification_n(a,n),1)).half0; }
static inline halfword tex_get_balance_vsize         (halfword a, halfword n) { return specification_index(a,balance_shape_slot(specification_n(a,n),1)).half1; }
static inline halfword tex_get_balance_topskip       (halfword a, halfword n) { return specification_index(a,balance_shape_slot(specification_n(a,n),2)).half0; }
static inline halfword tex_get_balance_bottomskip    (halfword a, halfword n) { return specification_index(a,balance_shape_slot(specification_n(a,n),2)).half1; }
static inline halfword tex_get_balance_options       (halfword a, halfword n) { return specification_index(a,balance_shape_slot(specification_n(a,n),3)).half0; }
static inline halfword tex_get_balance_extra         (halfword a, halfword n) { return specification_index(a,balance_shape_slot(specification_n(a,n),3)).half1; }
static inline halfword tex_get_balance_topdiscard    (halfword a, halfword n) { return specification_index(a,balance_shape_slot(specification_n(a,n),4)).half0; }
static inline halfword tex_get_balance_bottomdiscard (halfword a, halfword n) { return specification_index(a,balance_shape_slot(specification_n(a,n),4)).half1; }

/* balance passes */

static inline void tex_set_balance_passes_okay                (halfword a, halfword n, uint64_t v) { specification_index(a,balance_passes_slot(n,1)).long0   |= v; }
static inline void tex_set_balance_passes_features            (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,2)).quart00 |= (v & 0xFFFF); }
static inline void tex_set_balance_passes_classes             (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,2)).quart01 |= (v & 0xFFFF); }
static inline void tex_set_balance_passes_threshold           (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,3)).half1 = v; };
static inline void tex_set_balance_passes_demerits            (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,3)).half0 = v; };
static inline void tex_set_balance_passes_tolerance           (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,4)).half1 = v; };
static inline void tex_set_balance_passes_emergencyfactor     (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,4)).half0 = v; };
static inline void tex_set_balance_passes_emergencypercentage (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,5)).half1 = v; };
static inline void tex_set_balance_passes_emergencystretch    (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,5)).half0 = v; };
static inline void tex_set_balance_passes_fitnessclasses      (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,6)).half1 = v; };
static inline void tex_set_balance_passes_looseness           (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,6)).half0 = v; };
static inline void tex_set_balance_passes_pagebreakchecks     (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,7)).half1 = v; };
static inline void tex_set_balance_passes_pagepenalty         (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,7)).half0 = v; };
static inline void tex_set_balance_passes_adjdemerits         (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,8)).half1 = v; };
static inline void tex_set_balance_passes_reserved            (halfword a, halfword n, halfword v) { specification_index(a,balance_passes_slot(n,8)).half0 = v; };

static inline uint64_t tex_get_balance_passes_okay                (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,1)).long0;   };
static inline halfword tex_get_balance_passes_features            (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,2)).quart00; };
static inline halfword tex_get_balance_passes_classes             (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,2)).quart01; };
static inline halfword tex_get_balance_passes_threshold           (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,3)).half1;   };
static inline halfword tex_get_balance_passes_demerits            (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,3)).half0;   };
static inline halfword tex_get_balance_passes_tolerance           (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,4)).half1;   };
static inline halfword tex_get_balance_passes_emergencyfactor     (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,4)).half0;   };
static inline halfword tex_get_balance_passes_emergencypercentage (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,5)).half1;   };
static inline halfword tex_get_balance_passes_emergencystretch    (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,5)).half0;   };
static inline halfword tex_get_balance_passes_fitnessclasses      (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,6)).half1;   };
static inline halfword tex_get_balance_passes_looseness           (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,6)).half0;   };
static inline halfword tex_get_balance_passes_pagebreakchecks     (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,7)).half1;   };
static inline halfword tex_get_balance_passes_pagepenalty         (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,7)).half0;   };
static inline halfword tex_get_balance_passes_adjdemerits         (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,8)).half1;   };
static inline halfword tex_get_balance_passes_reserved            (halfword a, halfword n) { return specification_index(a,balance_passes_slot(n,8)).half0;   };

/* general */

extern        halfword tex_new_specification_node          (halfword n, quarterword s, halfword options);
extern        void     tex_dispose_specification_nodes     (void);
extern        void     tex_run_specification_spec          (void);
extern        halfword tex_scan_specifier                  (void);
extern        void     tex_aux_set_specification           (int a, halfword target);
extern        halfword tex_aux_get_specification_value     (int a, halfword code);

extern        void     tex_specification_range_error       (halfword target);

# endif