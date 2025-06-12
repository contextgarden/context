/*
    See license.txt in the root of this project.
*/

/*tex This is experimental code, and it might disappear. */

# ifndef LMT_SNAPPING_H
# define LMT_SNAPPING_H

# include "luametatex.h"

typedef enum snapping_methods {
    snapping_method_threshold = 0x0001,
    snapping_method_glyph     = 0x0010,
    snapping_method_rule      = 0x0020,
    snapping_method_list      = 0x0040,
    snapping_method_math      = 0x0080,
} box_snap_methods;

typedef struct snapping_specification {
    /* ideal dimensions */
    struct { 
        scaled height; 
        scaled depth;
    };
    /* thresholds */
    struct {
        scaled top;
        scaled bottom;
    };
    /* control */
    int method; 
} snapping_specification;

extern int  tex_snapping_needed  (snapping_specification *specification);
extern void tex_snapping_reset   (snapping_specification *specification);
extern int  tex_snapping_content (halfword first, halfword last, snapping_specification *specification);
extern int  tex_snapping_indeed  (halfword first, halfword last, snapping_specification *specification);

# endif 
