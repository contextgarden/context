/*tex

    This triangle library is mostly a by-product of some experiments by Mikael Sundqvist and Hans 
    Hagen with (pseudo) 3D rendering in \METAPOST. We wanted to detect intersecting triangles 
    in meshing and ran into a few solutions. We did some test in \LUA\ and for performance reasons
    decided to go for \CCODE, also because we were working on a related vector library. So, this 
    code is somewhat alien to \LUAMETATEX\ but occasionally we permit ourselves some deviation from 
    our \quotation {keep the engine lean and mean} principles. We also want to document experiments
    in a way that doesn't demand the use of some external library when it comes to \METAPOST.  

    We took the code from the resources mentioned below but adapted it to our needs, that is: a bit 
    different interfaces, some more granular return values, reformatting macros and c so that we 
    could better understand (and maybe optimize) some; we also made sure all was double okay. If we 
    introduced errors, blame us. 

*/ 

/*

    For the Moller variant, see license comment in the triangles.c file!

    https://fileadmin.cs.lth.se/cs/Personal/Tomas_Akenine-Moller/code/tritri_isectline.txt

    For Guigue & Devillers see:

    http://www.acm.org/jgt/papers/GuigueDevillers03/
    https://github.com/erich666/jgt-code/blob/master/Volume_08/Number_1/Guigue2003/tri_tri_intersect.c
    http://www.philippe-guigue.de/data/triangle_triangle_intersection.html

    There is overlap between the code, the main difference is in the part where the comparison
    happens after the initial tests fell trough. 

*/

# ifndef TRIANGLES_H
# define TRIANGLES_H

/*tex 
   
    For practical purposes we added more detailed feedback about the coplanar and overlap states 
    so that we can report on them later on. We also need more info in order to play with this. So 
    the interfaces are different than the original. 

    We found that the right setting of |EPSILON| played a huge rule in false positives so we 
    decided to make that a parameter. 

    MS & HH 
*/

# define triangles_epsilon    1.0e-06 // 0.000001
# define triangles_epsilon_gd 1.0e-16

typedef double triangles_two  [2] ;
typedef double triangles_three[3] ;

typedef enum triangles_intersection_states {
    /* we don't intersect: */
    triangles_intersection_nop_bound       = 0x00,
    triangles_intersection_nop_plane_one   = 0x01,
    triangles_intersection_nop_plane_two   = 0x02,
    triangles_intersection_nop_coplanar    = 0x03,
    triangles_intersection_nop_final       = 0x04,
    triangles_intersection_nop_same_points = 0x0E,
    triangles_intersection_nop_same_values = 0x0F,
    /* we intersect: */
    triangles_intersection_yes_bound       = 0x10,
    triangles_intersection_yes_unused_1    = 0x11,
    triangles_intersection_yes_unused_2    = 0x12,
    triangles_intersection_yes_coplanar    = 0x13,
    triangles_intersection_yes_final       = 0x14,
    /* */
} triangles_intersection_states;

/* Moller */

extern int triangles_intersect (
    triangles_three V0,
    triangles_three V1,
    triangles_three V2,
    triangles_three U0,
    triangles_three U1,
    triangles_three U2,
    double          epsilon
);

extern int triangles_intersect_with_line (
    triangles_three V0,
    triangles_three V1,
    triangles_three V2,
	triangles_three U0,
    triangles_three U1,
    triangles_three U2,
	triangles_three isectpt1,
    triangles_three isectpt2,
    double          epsilon
);

/* Guigue & Devillers */

extern int triangles_intersect_gd (
    triangles_three V0,
    triangles_three V1,
    triangles_three V2,
    triangles_three U0,
    triangles_three U1,
    triangles_three U2,
    double          epsilon
);

extern int triangles_intersect_with_line_gd (
    triangles_three V0,
    triangles_three V1,
    triangles_three V2,
    triangles_three U0,
    triangles_three U1,
    triangles_three U2,
    triangles_three source,
    triangles_three target,
    double          epsilon
);

extern int triangles_intersect_two_gd ( /* todo: return values */
    triangles_two V0,
    triangles_two V1,
    triangles_two V2,
    triangles_two U0,
    triangles_two U1,
    triangles_two U2,
    double        epsilon
);

# endif
