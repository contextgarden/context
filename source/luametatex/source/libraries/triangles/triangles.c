/*

    Triangle/triangle intersection test routine, by Tomas Moller, 1997.

    See article "A Fast Triangle-Triangle Intersection Test", Journal of Graphics Tools, 2(2), 1997

 */

 /*

    Copyright 2020 Tomas Akenine-Moller

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
    documentation files (the "Software"), to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
    to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
    WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
    OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT
    OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

/*tex

    When we were playing with vectors, matrices and mesh rendering in \METAPOST\ we ran into
    the code below. We use this code to improve the contour graphic generation where triangles
    in meshes can overlap. The code has been reformatted (so that we can better understand it)
    and adapted to interfacing with the vector code that we have.

    The code has been adapted to doubles instead of floats and also to get rid of some compiler
    warnings. Because we didn't get the expected results, we reshuffled some bits and pieces in
    order to make tracing a bit easier.

    We use the updated 2001-06-20 version and default to the variant without division. We also
    use a more granular response.

    triangles_intersection_states triangles_intersect (
        triangles_three V0,
        triangles_three V1,
        triangles_three V2,
        triangles_three U0,
        triangles_three U1,
        triangles_three U2
    )

    triangles_intersection_states triangles_intersect_with_line (
        triangles_three V0,
        triangles_three V1,
        triangles_three V2,
        triangles_three U0,
        triangles_three U1,
        triangles_three U2,
        triangles_three isectpt1, // endpoint 1
        triangles_three isectpt2  // endpoint 2
    );

    We shuffled the variables a bit so that we can see more clearly which ones are temporary. Of
    course we can use more inline functions. If there are errors, just blame:

    Mikael Sundqvist (same department as the author - Lund SV)
    Hans Hagen

*/

# include <math.h>
# include <stdio.h>
# include <triangles.h>

 /*
    A nice coincidence is that we also use this value in the vector library. Maybe using that
    iszero test is faster as we don't need to fabs. We have to use a much higher epsilon in 
    the caller because otherwise we get too many false positives here. (HH)
*/

// # if 0
// 
//     # define EPSILON    0.000001
//     # define ISZERO(d)  (d > -EPSILON && d < EPSILON)
//     # define USEZERO(d) (d > -EPSILON && d < EPSILON)
// 
// # else
// 
//     # define EPSILON    0.000001
//  // # define EPSILON    1.0e-16
//     # define ISZERO(d)  (d == 0.0)
//     # define USEZERO(d) (fabs(d) < EPSILON)
// 
// # endif

/*tex
    We started out with the Swedish EPSILON being \im {0.000001{$} but then the French one was
    \im {1.0e-16} which made us, also observing random false positives (which also relates to 
    the numbers involved), decide to make it a parameter. 
*/

# if 0

    # define ISZERO(d)  (d > -epsilon && d < epsilon)
    # define USEZERO(d) (d > -epsilon && d < epsilon)

# else

    # define ISZERO(d)  (d == 0.0)
    # define USEZERO(d) (fabs(d) < epsilon)

# endif

/* Here macros are faster than inline functions so we keep them. (HH) */

# define CROSS(dest,v1,v2) \
    dest[0] = v1[1] * v2[2] - v1[2] * v2[1]; \
    dest[1] = v1[2] * v2[0] - v1[0] * v2[2]; \
    dest[2] = v1[0] * v2[1] - v1[1] * v2[0];

# define DOT(v1,v2) \
    ( v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2] )

# define SUB(dest,v1,v2) \
    dest[0] = v1[0] - v2[0]; \
    dest[1] = v1[1] - v2[1]; \
    dest[2] = v1[2] - v2[2];

# define ADD(dest,v1,v2) \
    dest[0] = v1[0] + v2[0]; \
    dest[1] = v1[1] + v2[1]; \
    dest[2] = v1[2] + v2[2];

# define MULT(dest,v,factor) \
    dest[0] = factor * v[0]; \
    dest[1] = factor * v[1]; \
    dest[2] = factor * v[2];

# define SET(dest,src) \
    dest[0] = src[0]; \
    dest[1] = src[1]; \
    dest[2] = src[2];

/* sort so that a <= b */

# define SORT(a,b) \
    if (a > b) { \
        double c = a; \
        a = b; \
        b = c; \
    }

# define SORT2(a,b,smallest) \
    smallest = a > b; \
    if (smallest) { \
        double c = a; \
        a = b; \
        b = c; \
    }


/*
    This edge to edge test is based on Franlin Antonio's gem:
     "Faster Line Segment Intersection", in Graphics Gems III, pp. 199-202
*/

# define EDGE_EDGE_TEST(V0,U0,U1) \
    Bx = U0[i0] - U1[i0]; \
    By = U0[i1] - U1[i1]; \
    Cx = V0[i0] - U0[i0]; \
    Cy = V0[i1] - U0[i1]; \
    f = Ay * Bx - Ax * By; \
    d = By * Cx - Bx * Cy; \
    if ((f > 0.0 && d >= 0.0 && d <= f) || (f < 0.0 && d <= 0.0 && d >= f)) { \
        e = Ax * Cy - Ay * Cx; \
        if (f > 0.0) { \
            if (e >= 0.0 && e <= f) { \
                return 1; \
            } \
        } else { \
            if (e <= 0.0 && e >= f) { \
                return 1; \
            } \
        } \
    }

# define EDGE_AGAINST_TRI_EDGES(V0,V1,U0,U1,U2,i0,i1) \
{ \
    double Bx, By, Cx, Cy, e, d, f; \
    double Ax = V1[i0] - V0[i0];\
    double Ay = V1[i1] - V0[i1]; \
    /* test edge U0,U1 against V0,V1 */ \
    EDGE_EDGE_TEST(V0,U0,U1); \
    /* test edge U1,U2 against V0,V1 */ \
    EDGE_EDGE_TEST(V0,U1,U2); \
    /* test edge U2,U0 against V0,V1 */ \
    EDGE_EDGE_TEST(V0,U2,U0); \
}

# define POINT_IN_TRI(V0,U0,U1,U2,i0,i1) \
{ \
    double a, b, c, d0, d1, d2; \
    /* is T1 completely inside T2? check if V0 is inside tri(U0,U1,U2) */ \
    a =    U1[i1] - U0[i1]; \
    b = - (U1[i0] - U0[i0]); \
    c = - a * U0[i0] - b * U0[i1]; \
    d0 =  a * V0[i0] + b * V0[i1] + c; \
    /* */ \
    a =    U2[i1] - U1[i1]; \
    b = - (U2[i0] - U1[i0]); \
    c = - a * U1[i0] - b * U1[i1]; \
    d1 =  a * V0[i0] + b * V0[i1] + c; \
    /* */ \
    a =    U0[i1] - U2[i1]; \
    b = - (U0[i0] - U2[i0]); \
    c = - a * U2[i0] - b * U2[i1]; \
    d2 =  a * V0[i0] + b * V0[i1] + c; \
    /* */ \
    if ((d0 * d1 > 0.0) && (d0 * d2 > 0.0)) { \
        return 1; \
    } \
}

static inline int triangles_are_coplanar(
    triangles_three N,
    triangles_three V0,
    triangles_three V1,
    triangles_three V2,
    triangles_three U0,
    triangles_three U1,
    triangles_three U2
)
{
    triangles_three A;
    int i0, i1;

    /* first project onto an axis-aligned plane, that maximizes the area */
    /* of the triangles, compute indices i0 and i1 */

    A[0] = fabs(N[0]);
    A[1] = fabs(N[1]);
    A[2] = fabs(N[2]);
    if (A[0] > A[1]) {
        if (A[0] > A[2]) {
            i0 = 1; i1 = 2;
        } else {
            i0 = 0; i1 = 1;
        }
    } else {
        if (A[2] > A[1]) {
            i0 = 0; i1 = 1;
        } else {
            i0 = 0; i1 = 2;
        }
    }

    /* test all edges of triangle 1 against the edges of triangle 2 */

    EDGE_AGAINST_TRI_EDGES(V0,V1,U0,U1,U2,i0,i1);
    EDGE_AGAINST_TRI_EDGES(V1,V2,U0,U1,U2,i0,i1);
    EDGE_AGAINST_TRI_EDGES(V2,V0,U0,U1,U2,i0,i1);

    /* finally, test if tri1 is totally contained in tri2 or vice versa */

    POINT_IN_TRI(V0,U0,U1,U2,i0,i1);
    POINT_IN_TRI(U0,V0,V1,V2,i0,i1);

    return 0;
}

/* D1D2 added for cleaner code ... there is no gain in avoiding it */

# define INTERVALS_2(VV,DD,D0D1,D0D2,A,B,C,X0,X1) \
{ \
    A = VV[2]; B = (VV[0] - VV[2]) * DD[2]; C = (VV[1] - VV[2]) * DD[2]; X0 = DD[2] - DD[0]; X1 = DD[2] - DD[1]; \
}

# define INTERVALS_1(VV,DD,D0D1,D0D2,A,B,C,X0,X1) \
{ \
    A = VV[1]; B = (VV[0] - VV[1]) * DD[1]; C = (VV[2] - VV[1]) * DD[1]; X0 = DD[1] - DD[0]; X1 = DD[1] - DD[2]; \
}

# define INTERVALS_0(VV,DD,D0D1,D0D2,A,B,C,X0,X1) \
{ \
    A = VV[0]; B = (VV[1] - VV[0]) * DD[0]; C = (VV[2] - VV[0]) * DD[0]; X0 = DD[0] - DD[1]; X1 = DD[0] - DD[2]; \
}

# define COMPUTE_INTERVALS(VV,DD,D0D1,D0D2,D1D2,A,B,C,X0,X1,V0,V1,V2,U0,U1,U2) \
{ \
    if (D0D1 > 0.0) { \
        INTERVALS_2(VV,DD,D0D1,D0D2,A,B,C,X0,X1) \
    } else if (D0D2 > 0.0) { \
        INTERVALS_1(VV,DD,D0D1,D0D2,A,B,C,X0,X1) \
    } else if (D1D2 > 0.0) { \
        INTERVALS_0(VV,DD,D0D1,D0D2,A,B,C,X0,X1) \
    } else if (! ISZERO(DD[0])) { \
        INTERVALS_0(VV,DD,D0D1,D0D2,A,B,C,X0,X1) \
    } else if (! ISZERO(DD[1])) { \
        INTERVALS_1(VV,DD,D0D1,D0D2,A,B,C,X0,X1) \
    } else if (! ISZERO(DD[2])) { \
        INTERVALS_2(VV,DD,D0D1,D0D2,A,B,C,X0,X1) \
    } else if (triangles_are_coplanar(N1, V0, V1, V2, U0, U1, U2)) {\
        return triangles_intersection_yes_coplanar; \
    } else { \
        return triangles_intersection_nop_coplanar; \
    } \
}

int triangles_intersect( /* We use the no_div variant! */
    triangles_three V0,
    triangles_three V1,
    triangles_three V2,
    triangles_three U0,
    triangles_three U1,
    triangles_three U2,
    double          epsilon
)
{
    triangles_three N1, N2;
    triangles_three dv, du;
    triangles_two isect1, isect2;
    double du0du1, du0du2, du1du2, dv0dv1, dv0dv2, dv1dv2;
    int index;

    /* compute plane equation of triangle(V0,V1,V2) */

    {
        double d1;
        triangles_three E1, E2;

        SUB(E1,V1,V0);
        SUB(E2,V2,V0);
        CROSS(N1,E1,E2);
        d1 = -DOT(N1,V0);

        /* plane equation 1: N1.X + d1 = 0 */

        /* put U0,U1,U2 into plane equation 1 to compute signed distances to the plane*/

        du[0] = DOT(N1,U0) + d1;
        du[1] = DOT(N1,U1) + d1;
        du[2] = DOT(N1,U2) + d1;

        if (USEZERO(du[0])) du[0] = 0.0;
        if (USEZERO(du[1])) du[1] = 0.0;
        if (USEZERO(du[2])) du[2] = 0.0;

        du0du1 = du[0] * du[1];
        du0du2 = du[0] * du[2];
        du1du2 = du[1] * du[2];

        /* if same sign on all of them + not equal 0 then no intersection occurs */

        if (du0du1 > 0.0 && du0du2 > 0.0) {
            return triangles_intersection_nop_plane_one;
        }

    }

    /* compute plane of triangle (U0,U1,U2) */

    {
        double d2;
        triangles_three E1, E2;

        SUB(E1,U1,U0);
        SUB(E2,U2,U0);
        CROSS(N2,E1,E2);
        d2 = -DOT(N2,U0);

        /* plane equation 2: N2.X + d2 = 0 */

        /* put V0, V1, V2 into plane equation 2 */

        dv[0] = DOT(N2,V0) + d2;
        dv[1] = DOT(N2,V1) + d2;
        dv[2] = DOT(N2,V2) + d2;

        if (USEZERO(dv[0])) dv[0] = 0.0;
        if (USEZERO(dv[1])) dv[1] = 0.0;
        if (USEZERO(dv[2])) dv[2] = 0.0;

        dv0dv1 = dv[0] * dv[1];
        dv0dv2 = dv[0] * dv[2];
        dv1dv2 = dv[1] * dv[2];

        /* if same sign on all of them + not equal 0 then no intersection occurs */

        if (dv0dv1 > 0.0 && dv0dv2 > 0.0) {
            return triangles_intersection_nop_plane_two;
        }

    }

    {
        /* compute direction of intersection line and index to the largest component of D */

        triangles_three D; CROSS(D,N1,N2);

        D[0] = fabs(D[0]); D[1] = fabs(D[1]); D[2] = fabs(D[2]);

        if (D[2] > D[0]) {
            index = D[2] > D[0] ? 2 : 1;
        } else {
            index = D[2] > D[0] ? 2 : 0;
        }

    }

    /* this is the simplified projection onto L */

    {

        double a, b, c, x0, x1;
        double d, e, f, y0, y1;

        /* compute interval for triangle 1 */

        {
            triangles_three vp; vp[0] = V0[index]; vp[1] = V1[index]; vp[2] = V2[index];

            COMPUTE_INTERVALS(vp,dv,dv0dv1,dv0dv2,dv1dv2,a,b,c,x0,x1,V0,V1,V2,U0,U1,U2);

        }

        /* compute interval for triangle 2 */

        {
            triangles_three up; up[0] = U0[index]; up[1] = U1[index]; up[2] = U2[index];

            COMPUTE_INTERVALS(up,du,du0du1,du0du2,du1du2,d,e,f,y0,y1,V0,V1,V2,U0,U1,U2);

        }

        /* we fall through */

        {
            double xx = x0 * x1;
            double yy = y0 * y1;
            double xxyy = xx * yy;

            {
                double tmp = a * xxyy;
                isect1[0] = tmp + b * x1 * yy;
                isect1[1] = tmp + c * x0 * yy;
            }

            {
                double tmp = d * xxyy;
                isect2[0] = tmp + e * xx * y1;
                isect2[1] = tmp + f * xx * y0;
            }
        }

    }

    SORT(isect1[0],isect1[1]);
    SORT(isect2[0],isect2[1]);

    return (isect1[1] < isect2[0] || isect2[1] < isect1[0])
      ? triangles_intersection_nop_final
      : triangles_intersection_yes_final;

}

static inline void check_isect(
    triangles_three  VTX0,
    triangles_three  VTX1,
    triangles_three  VTX2,
    double           VV0,
    double           VV1,
    double           VV2,
	double           D0,
    double           D1,
    double           D2,
    double          *isect0,
    double          *isect1,
    triangles_three  isectpoint0,
    triangles_three  isectpoint1
)
{
    double tmp = D0 / (D0 - D1);
    triangles_three diff;
    *isect0 = VV0 + (VV1 - VV0) * tmp;
    SUB(diff,VTX1,VTX0);
    MULT(diff,diff,tmp);
    ADD(isectpoint0,diff,VTX0);
    tmp = D0 / (D0 - D2);
    *isect1 = VV0 + (VV2 - VV0) * tmp;
    SUB(diff,VTX2,VTX0);
    MULT(diff,diff,tmp);
    ADD(isectpoint1,VTX0,diff);
}

static inline int compute_intervals_coplanar(
    triangles_three  VERT0,
    triangles_three  VERT1,
    triangles_three  VERT2,
	triangles_three  VV,
    triangles_three  D,
	double           D0D1,
    double           D0D2,
    double           D1D2,
    double          *isect0,
    double          *isect1,
	triangles_three  isectpoint0,
    triangles_three  isectpoint1
)
{
    if (D0D1 > 0.0) {
        check_isect(VERT2, VERT0, VERT1, VV[2], VV[0], VV[1], D[2], D[0], D[1], isect0, isect1, isectpoint0, isectpoint1);
    } else if (D0D2 > 0.0) {
        check_isect(VERT1, VERT0, VERT2, VV[1], VV[0], VV[2], D[1], D[0], D[2], isect0, isect1, isectpoint0, isectpoint1);
    } else if (D1D2 > 0.0) {
        check_isect(VERT0, VERT1, VERT2, VV[0], VV[1], VV[2], D[0], D[1], D[2], isect0, isect1, isectpoint0, isectpoint1);
    } else if (! ISZERO(D[0])) {
        check_isect(VERT0, VERT1, VERT2, VV[0], VV[1], VV[2], D[0], D[1], D[2], isect0, isect1, isectpoint0, isectpoint1);
    } else if (! ISZERO(D[1])) {
        check_isect(VERT1, VERT0, VERT2, VV[1], VV[0], VV[2], D[1], D[0], D[2], isect0, isect1, isectpoint0, isectpoint1);
    } else if (! ISZERO(D[2])) {
        check_isect(VERT2, VERT0, VERT1, VV[2], VV[0], VV[1], D[2], D[0], D[1], isect0, isect1, isectpoint0, isectpoint1);
    } else {
        return 1; /* triangles are coplanar */
    }
    return 0;
}

/*
    If we use this as follow up it can best be more the same a the above one. The coplanar
    return value is kind of weird because it can be true while there is also this check, so
    one should check
*/

int triangles_intersect_with_line(
    triangles_three V0,
    triangles_three V1,
    triangles_three V2,
    triangles_three U0,
    triangles_three U1,
    triangles_three U2,
    triangles_three isectpt1,
    triangles_three isectpt2,
    double          epsilon
)
{
    triangles_three N1, N2;
    triangles_three du, dv;
    triangles_two isect1 = { 0.0, 0.0 }; /* compiler initialization warning when unset */
    triangles_two isect2 = { 0.0, 0.0 };
    triangles_three isectpointA1 = { 0.0, 0.0, 0.0 }; /* compiler initialization warning when unset */
    triangles_three isectpointA2 = { 0.0, 0.0, 0.0 };
    triangles_three isectpointB1 = { 0.0, 0.0, 0.0 };
    triangles_three isectpointB2 = { 0.0, 0.0, 0.0 };
    double du0du1, du0du2, du1du2, dv0dv1, dv0dv2, dv1dv2;
    int index;

    /* compute plane equation of triangle(V0,V1,V2) */

    {

        double d1;
        triangles_three E1, E2;

        SUB(E1,V1,V0);
        SUB(E2,V2,V0);
        CROSS(N1,E1,E2);
        d1 = -DOT(N1,V0);

        /* plane equation 1: N1.X + d1 = 0 */

        /* put U0, U1, U2 into plane equation 1 to compute signed distances to the plane */

        du[0] = DOT(N1,U0) + d1;
        du[1] = DOT(N1,U1) + d1;
        du[2] = DOT(N1,U2) + d1;

        /* coplanarity robustness check */

        if (USEZERO(du[0])) du[0] = 0.0;
        if (USEZERO(du[1])) du[1] = 0.0;
        if (USEZERO(du[2])) du[2] = 0.0;

        du0du1 = du[0] * du[1];
        du0du2 = du[0] * du[2];
        du1du2 = du[1] * du[2];

        /* same sign on all of them + not equal 0 then no intersection occurs */

        if (du0du1 > 0.0 && du0du2 > 0.0) {
            return triangles_intersection_nop_plane_one;
        }

    }

    /* compute plane of triangle (U0,U1,U2) */

    {

        double d2;
        triangles_three E1, E2;

        SUB(E1,U1,U0);
        SUB(E2,U2,U0);
        CROSS(N2,E1,E2);
        d2 = -DOT(N2,U0);

        /* plane equation 2: N2.X + d2 = 0 */

        /* put V0, V1, V2 into plane equation 2 */

        dv[0] = DOT(N2,V0) + d2;
        dv[1] = DOT(N2,V1) + d2;
        dv[2] = DOT(N2,V2) + d2;

        if (USEZERO(dv[0])) dv[0] = 0.0;
        if (USEZERO(dv[1])) dv[1] = 0.0;
        if (USEZERO(dv[2])) dv[2] = 0.0;

        dv0dv1 = dv[0] * dv[1];
        dv0dv2 = dv[0] * dv[2];
        dv1dv2 = dv[1] * dv[2];

        /* same sign on all of them + not equal 0 then no intersection occurs */

        if (dv0dv1 > 0.0 && dv0dv2 > 0.0) {
            return triangles_intersection_nop_plane_two;
        }

    }

    {

        /* compute direction of intersection line and index to the largest component of D */

        triangles_three D; CROSS(D,N1,N2);

        D[0] = fabs(D[0]); D[1] = fabs(D[1]); D[2] = fabs(D[2]);

        if (D[1] > D[0]) {
            index = D[2] > D[0] ? 2 : 1;
        } else {
            index = D[2] > D[0] ? 2 : 0;
        }

    }

    /* this is the simplified projection onto L */

    {
        triangles_three vp; vp[0] = V0[index]; vp[1] = V1[index]; vp[2] = V2[index];

        /* compute interval for triangle 1 */

        if (compute_intervals_coplanar(V0, V1, V2, vp, dv, dv0dv1, dv0dv2, dv1dv2, &isect1[0], &isect1[1], isectpointA1, isectpointA2)) {
            return triangles_are_coplanar(N1, V0, V1, V2, U0, U1, U2) 
                ? triangles_intersection_yes_coplanar 
                : triangles_intersection_nop_coplanar;
        }

    }

    /* compute interval for triangle 2 */

    {
        triangles_three up; up[0] = U0[index]; up[1] = U1[index]; up[2] = U2[index];

        if (compute_intervals_coplanar(U0, U1, U2, up, du, du0du1, du0du2, du1du2, &isect2[0], &isect2[1], isectpointB1, isectpointB2)) {
            /*
                We should never end up here but as we have it in the non_div version too
                we added this redundant coplanar check if only because we have these possible
                return values.
            */
            return triangles_are_coplanar(N1, V0, V1, V2, U0, U1, U2)
                ? triangles_intersection_yes_coplanar 
                : triangles_intersection_nop_coplanar;
        }

    }

    {

        int smallest1, smallest2;

        SORT2(isect1[0],isect1[1],smallest1);
        SORT2(isect2[0],isect2[1],smallest2);

        if (isect1[1] < isect2[0] || isect2[1] < isect1[0]) {
            return triangles_intersection_nop_final;
        }

        /* at this point, we know that the triangles intersect */

        if (isect2[0] < isect1[0]) {
            if (smallest1 == 0.0) {
                SET(isectpt1,isectpointA1);
            } else {
                SET(isectpt1,isectpointA2);
            }
            if (isect2[1] < isect1[1]) {
                if (smallest2 == 0.0) {
                    SET(isectpt2,isectpointB2);
                } else {
                    SET(isectpt2,isectpointB1);
                }
            } else {
                if (smallest1 == 0.0) {
                    SET(isectpt2,isectpointA2);
                }else {
                    SET(isectpt2,isectpointA1);
                }
            }
        } else {
            if (smallest2 == 0.0) {
                SET(isectpt1,isectpointB1);
            } else {
                SET(isectpt1,isectpointB2);
            }
            if (isect2[1] > isect1[1]) {
                if (smallest1 == 0.0) {
                    SET(isectpt2,isectpointA2);
                } else {
                    SET(isectpt2,isectpointA1);
                }
            } else {
                if (smallest2 == 0.0) {
                    SET(isectpt2,isectpointB2);
                } else {
                    SET(isectpt2,isectpointB1);
                }
            }
        }

        return triangles_intersection_yes_final;

    }
}

/*

    Triangle-Triangle Overlap Test Routines
    July, 2002
    Updated December 2003
    
    http://www.acm.org/jgt/papers/GuigueDevillers03/
    https://github.com/erich666/jgt-code/blob/master/Volume_08/Number_1/Guigue2003/tri_tri_intersect.c
    http://www.philippe-guigue.de/data/triangle_triangle_intersection.html
    
    This file contains C implementation of algorithms for performing two and three-dimensional 
    triangle-triangle intersection test. The algorithms and underlying theory are described in
    
        Fast and Robust Triangle-Triangle Overlap Test
        Using Orientation Predicates"  P. Guigue - O. Devillers
        Journal of Graphics Tools, 8(1), 2003
    
    Several geometric predicates are defined.  Their parameters are all points. Each point is an 
    array of two or three double precision floating point numbers. The geometric predicates 
    implemented in this file are:
    
        int triangles_intersect_gd           (p1,q1,r1,p2,q2,r2)
        int triangles_intersect_two_gd       (p1,q1,r1,p2,q2,r2)
        int triangles_intersect_with_line_gd (p1,q1,r1,p2,q2,r2,source,target)
        
    Each function returns 1 if the triangles (including their boundary) intersect, otherwise 0.
    
*/

/* 
    The code has reformatted by HH because (1) we want to see what happens, (2) we need to interface
    it to our own code, (3) we don't want to cast doubles to 0.0f and above all (4) we want to see
    the differences between several methods.
*/

/*
    Three-dimensional Triangle-Triangle Overlap Test. It additionally computes the segment of
    intersection of the two triangles if it exists. The coplanar variable returns whether the
    triangles are coplanar, source and target are the endpoints of the line segment of
    intersection.
*/

/*
    The optional EPSILON test (controlled by USE_EPSILON_TEST) has been replaced by USEZERO that 
    we use in the Moller variant above. Here 1e-16 was used while Moller uses a larger value. 

    We also share some macros with the previous definitions; SCALAR is like MUL but with a 
    different parameter order.

*/

# define SCALAR(dest,alpha,v) \
    dest[0] = alpha * v[0]; \
    dest[1] = alpha * v[1]; \
    dest[2] = alpha * v[2];

# define CHECK_MIN_MAX(p1,q1,r1,p2,q2,r2) { \
    SUB(v1,p2,q1) \
    SUB(v2,p1,q1) \
    CROSS(N1,v1,v2) \
    SUB(v1,q2,q1) \
    if (DOT(v1,N1) > 0.0) { \
        return triangles_intersection_nop_final; \
    } \
    SUB(v1,p2,p1) \
    SUB(v2,r1,p1) \
    CROSS(N1,v1,v2) \
    SUB(v1,r2,p1) \
    if (DOT(v1,N1) > 0.0) { \
        return triangles_intersection_nop_final; \
    } else { \
        return triangles_intersection_yes_final; \
    } \
}

static int triangles_are_coplanar_gd(
    triangles_three p1,
    triangles_three q1,
    triangles_three r1,
    triangles_three p2,
    triangles_three q2,
    triangles_three r2,
    triangles_three normal_1,
    double          epsilon
)
{

    triangles_two P1, Q1, R1;
    triangles_two P2, Q2, R2;

    double n_x = normal_1[0] < 0.0 ? -normal_1[0] : normal_1[0];
    double n_y = normal_1[1] < 0.0 ? -normal_1[1] : normal_1[1];
    double n_z = normal_1[2] < 0.0 ? -normal_1[2] : normal_1[2];

    /* Projection of the triangles in 3D onto 2D such that the area of the projection is maximized. */

    if (n_x > n_z && n_x >= n_y) {
        /* Project onto plane YZ */
        P1[0] = q1[2]; P1[1] = q1[1]; Q1[0] = p1[2]; Q1[1] = p1[1]; R1[0] = r1[2]; R1[1] = r1[1];
        P2[0] = q2[2]; P2[1] = q2[1]; Q2[0] = p2[2]; Q2[1] = p2[1]; R2[0] = r2[2]; R2[1] = r2[1];
    } else if (n_y > n_z && n_y >= n_x) {
        /* Project onto plane XZ */
        P1[0] = q1[0]; P1[1] = q1[2]; Q1[0] = p1[0]; Q1[1] = p1[2]; R1[0] = r1[0]; R1[1] = r1[2];
        P2[0] = q2[0]; P2[1] = q2[2]; Q2[0] = p2[0]; Q2[1] = p2[2]; R2[0] = r2[0]; R2[1] = r2[2];
    } else {
        /* Project onto plane XY */
        P1[0] = p1[0]; P1[1] = p1[1]; Q1[0] = q1[0]; Q1[1] = q1[1]; R1[0] = r1[0]; R1[1] = r1[1];
        P2[0] = p2[0]; P2[1] = p2[1]; Q2[0] = q2[0]; Q2[1] = q2[1]; R2[0] = r2[0]; R2[1] = r2[1];
    }

    return triangles_intersect_two_gd(P1,Q1,R1,P2,Q2,R2,epsilon);
};

/* Permutation in a canonical form of T2's vertices */

# define TRI_TRI_3D(p1,q1,r1,p2,q2,r2,dp2,dq2,dr2) { \
    if (dp2 > 0.0) { \
        if (dq2 > 0.0) { \
            CHECK_MIN_MAX(p1,r1,q1,r2,p2,q2) \
        } else if (dr2 > 0.0) { \
            CHECK_MIN_MAX(p1,r1,q1,q2,r2,p2) \
        } else { \
            CHECK_MIN_MAX(p1,q1,r1,p2,q2,r2) \
        } \
    } else if (dp2 < 0.0) { \
        if (dq2 < 0.0) { \
            CHECK_MIN_MAX(p1,q1,r1,r2,p2,q2)\
        } else if (dr2 < 0.0) { \
            CHECK_MIN_MAX(p1,q1,r1,q2,r2,p2)\
        } else { \
            CHECK_MIN_MAX(p1,r1,q1,p2,q2,r2) \
        } \
    } else if (dq2 < 0.0) { \
        if (dr2 >= 0.0) { \
            CHECK_MIN_MAX(p1,r1,q1,q2,r2,p2) \
        } else { \
            CHECK_MIN_MAX(p1,q1,r1,p2,q2,r2) \
        } \
    } else if (dq2 > 0.0) { \
        if (dr2 > 0.0) { \
            CHECK_MIN_MAX(p1,r1,q1,p2,q2,r2) \
        } else { \
            CHECK_MIN_MAX(p1,q1,r1,q2,r2,p2) \
        } \
    } else if (dr2 > 0.0) { \
        CHECK_MIN_MAX(p1,q1,r1,r2,p2,q2) \
    } else if (dr2 < 0.0) { \
        CHECK_MIN_MAX(p1,r1,q1,r2,p2,q2) \
    } else { \
        return triangles_are_coplanar_gd(p1,q1,r1,p2,q2,r2,N1,epsilon) \
           ? triangles_intersection_yes_coplanar \
           : triangles_intersection_nop_coplanar; \
    } \
}

/* Three-dimensional Triangle-Triangle Overlap Test */

int triangles_intersect_gd(
    triangles_three p1,
    triangles_three q1,
    triangles_three r1,
    triangles_three p2,
    triangles_three q2,
    triangles_three r2,
    double          epsilon
)
{
    double dp1, dq1, dr1, dp2, dq2, dr2;
    triangles_three v1, v2;
    triangles_three N1, N2;

  /* Compute distance signs  of p1, q1 and r1 to the plane of triangle(p2,q2,r2) */

    SUB(v1,p2,r2)
    SUB(v2,q2,r2)
    CROSS(N2,v1,v2)

    SUB(v1,p1,r2)  dp1 = DOT(v1,N2);
    SUB(v1,q1,r2)  dq1 = DOT(v1,N2);
    SUB(v1,r1,r2)  dr1 = DOT(v1,N2);

    /* coplanarity robustness check */

    if (USEZERO(dp1)) dp1 = 0.0;
    if (USEZERO(dq1)) dq1 = 0.0;
    if (USEZERO(dr1)) dr1 = 0.0;

    if (dp1 * dq1 > 0.0 && dp1 * dr1 > 0.0) {
        return triangles_intersection_nop_plane_one; 
    }

    /* Compute distance signs of p2, q2 and r2 to the plane of triangle(p1,q1,r1) */

    SUB(v1,q1,p1)
    SUB(v2,r1,p1)
    CROSS(N1,v1,v2)

    SUB(v1,p2,r1)  dp2 = DOT(v1,N1);
    SUB(v1,q2,r1)  dq2 = DOT(v1,N1);
    SUB(v1,r2,r1)  dr2 = DOT(v1,N1);

    if (USEZERO(dp2)) dp2 = 0.0;
    if (USEZERO(dq2)) dq2 = 0.0;
    if (USEZERO(dr2)) dr2 = 0.0;

    if (dp2 * dq2 > 0.0 && dp2 * dr2 > 0.0) {
        return triangles_intersection_nop_plane_two; 
    }

    /* Permutation in a canonical form of T1's vertices */

    if (dp1 > 0.0) {
        if (dq1 > 0.0) {
            TRI_TRI_3D(r1,p1,q1,p2,r2,q2,dp2,dr2,dq2)
        } else if (dr1 > 0.0)  {
            TRI_TRI_3D(q1,r1,p1,p2,r2,q2,dp2,dr2,dq2)
        } else {
            TRI_TRI_3D(p1,q1,r1,p2,q2,r2,dp2,dq2,dr2)
        }
    } else if (dp1 < 0.0) {
        if (dq1 < 0.0) {
            TRI_TRI_3D(r1,p1,q1,p2,q2,r2,dp2,dq2,dr2)
        } else if (dr1 < 0.0)  {
            TRI_TRI_3D(q1,r1,p1,p2,q2,r2,dp2,dq2,dr2)
        } else {
            TRI_TRI_3D(p1,q1,r1,p2,r2,q2,dp2,dr2,dq2)
        }
    } else if (dq1 < 0.0) {
        if (dr1 >= 0.0) {
            TRI_TRI_3D(q1,r1,p1,p2,r2,q2,dp2,dr2,dq2)
        } else {
            TRI_TRI_3D(p1,q1,r1,p2,q2,r2,dp2,dq2,dr2)
        }
    } else if (dq1 > 0.0) {
        if (dr1 > 0.0) {
            TRI_TRI_3D(p1,q1,r1,p2,r2,q2,dp2,dr2,dq2)
        } else {
            TRI_TRI_3D(q1,r1,p1,p2,q2,r2,dp2,dq2,dr2)
        }
    } else if (dr1 > 0.0) {
        TRI_TRI_3D(r1,p1,q1,p2,q2,r2,dp2,dq2,dr2)
    } else if (dr1 < 0.0) {
        TRI_TRI_3D(r1,p1,q1,p2,r2,q2,dp2,dr2,dq2)
    } else {
        return triangles_are_coplanar_gd(p1,q1,r1,p2,q2,r2,N1,epsilon)
            ? triangles_intersection_nop_coplanar 
            : triangles_intersection_yes_coplanar;
    }
}

/* Three-dimensional Triangle-Triangle Intersection */

/*
    This macro is called when the triangles surely intersect. It constructs the segment of
    intersection of the two triangles if they are not coplanar.

    NOTE: a faster, but possibly less precise, method of computing point B is described in:
    
        https://github.com/erich666/jgt-code/issues/5

    The if and else branches shared some (final) code so that has been moved out and is 
    shared (HH).
*/

# define CONSTRUCT_INTERSECTION(p1,q1,r1,p2,q2,r2) { \
    double alpha; \
    SUB(v1,q1,p1) \
    SUB(v2,r2,p1) \
    CROSS(N,v1,v2) \
    SUB(v,p2,p1) \
    if (DOT(v,N) > 0.0) { \
        SUB(v1,r1,p1) \
        CROSS(N,v1,v2) \
        if (DOT(v,N) <= 0.0) { \
            SUB(v2,q2,p1) \
            CROSS(N,v1,v2) \
            if (DOT(v,N) > 0.0) { \
                SUB(v1,p1,p2) \
                SUB(v2,p1,r1) \
                alpha = DOT(v1,N2) / DOT(v2,N2); \
                SCALAR(v1,alpha,v2) \
                SUB(source,p1,v1) \
            } else { \
                SUB(v1,p2,p1) \
                SUB(v2,p2,q2) \
                alpha = DOT(v1,N1) / DOT(v2,N1); \
                SCALAR(v1,alpha,v2) \
                SUB(source,p2,v1) \
            } \
            SUB(v1,p2,p1) \
            SUB(v2,p2,r2) \
            alpha = DOT(v1,N1) / DOT(v2,N1); \
            SCALAR(v1,alpha,v2) \
            SUB(target,p2,v1) \
            return triangles_intersection_yes_final; \
        } else { \
            return triangles_intersection_nop_final; \
        } \
    } else { \
        SUB(v2,q2,p1) \
        CROSS(N,v1,v2) \
        if (DOT(v,N) < 0.0) { \
            return triangles_intersection_nop_final; \
        } else { \
            SUB(v1,r1,p1) \
            CROSS(N,v1,v2) \
            if (DOT(v,N) >= 0.0) { \
                SUB(v1,p1,p2) \
                SUB(v2,p1,r1) \
                alpha = DOT(v1,N2) / DOT(v2,N2); \
                SCALAR(v1,alpha,v2) \
                SUB(source,p1,v1) \
            } else { \
                SUB(v1,p2,p1) \
                SUB(v2,p2,q2) \
                alpha = DOT(v1,N1) / DOT(v2,N1); \
                SCALAR(v1,alpha,v2) \
                SUB(source,p2,v1) \
            } \
            SUB(v1,p1,p2) \
            SUB(v2,p1,q1) \
            alpha = DOT(v1,N2) / DOT(v2,N2); \
            SCALAR(v1,alpha,v2) \
            SUB(target,p1,v1) \
            return triangles_intersection_yes_final; \
        } \
    } \
}

# define TRI_TRI_INTER_3D(p1,q1,r1,p2,q2,r2,dp2,dq2,dr2) { \
    if (dp2 > 0.0) { \
        if (dq2 > 0.0) { \
            CONSTRUCT_INTERSECTION(p1,r1,q1,r2,p2,q2) \
        } else if (dr2 > 0.0) { \
            CONSTRUCT_INTERSECTION(p1,r1,q1,q2,r2,p2) \
        } else { \
            CONSTRUCT_INTERSECTION(p1,q1,r1,p2,q2,r2) \
        } \
    } else if (dp2 < 0.0) { \
        if (dq2 < 0.0) { \
            CONSTRUCT_INTERSECTION(p1,q1,r1,r2,p2,q2) \
        } else if (dr2 < 0.0) { \
            CONSTRUCT_INTERSECTION(p1,q1,r1,q2,r2,p2) \
        } else { \
            CONSTRUCT_INTERSECTION(p1,r1,q1,p2,q2,r2) \
        } \
    } else if (dq2 < 0.0) { \
        if (dr2 >= 0.0) { \
            CONSTRUCT_INTERSECTION(p1,r1,q1,q2,r2,p2) \
        } else { \
            CONSTRUCT_INTERSECTION(p1,q1,r1,p2,q2,r2) \
        } \
    } else if (dq2 > 0.0) { \
        if (dr2 > 0.0)  { \
            CONSTRUCT_INTERSECTION(p1,r1,q1,p2,q2,r2) \
        } else { \
            CONSTRUCT_INTERSECTION(p1,q1,r1,q2,r2,p2) \
        } \
    } else if (dr2 > 0.0) { \
        CONSTRUCT_INTERSECTION(p1,q1,r1,r2,p2,q2) \
    } else if (dr2 < 0.0) { \
        CONSTRUCT_INTERSECTION(p1,r1,q1,r2,p2,q2) \
    } else { \
        return triangles_are_coplanar_gd(p1,q1,r1,p2,q2,r2,N1,epsilon) \
           ? triangles_intersection_nop_coplanar \
           : triangles_intersection_yes_coplanar; \
    } \
}

/*
   The following version computes the segment of intersection of the two triangles if it exists.
   coplanar returns whether the triangles are coplanar source and target are the endpoints of the
   line segment of intersection.
*/

int triangles_intersect_with_line_gd(
    triangles_three p1,
    triangles_three q1,
    triangles_three r1,
    triangles_three p2,
    triangles_three q2,
    triangles_three r2,
    triangles_three source,
    triangles_three target,
    double          epsilon
)
{
    double dp1, dq1, dr1, dp2, dq2, dr2;
    triangles_three v1, v2, v;
    triangles_three N1, N2, N;

    /* Compute distance signs  of p1, q1 and r1 to the plane of triangle(p2,q2,r2) */

    SUB(v1,p2,r2)
    SUB(v2,q2,r2)
    CROSS(N2,v1,v2)

    SUB(v1,p1,r2)  dp1 = DOT(v1,N2);
    SUB(v1,q1,r2)  dq1 = DOT(v1,N2);
    SUB(v1,r1,r2)  dr1 = DOT(v1,N2);

    /* coplanarity robustness check */

    if (USEZERO(dp1)) dp1 = 0.0;
    if (USEZERO(dq1)) dq1 = 0.0;
    if (USEZERO(dr1)) dr1 = 0.0;

    if (dp1 * dq1 > 0.0 && dp1 * dr1 > 0.0) {
        return triangles_intersection_nop_plane_one; 
    }

    // Compute distance signs  of p2, q2 and r2 to the plane of triangle(p1,q1,r1)

    SUB(v1,q1,p1)
    SUB(v2,r1,p1)
    CROSS(N1,v1,v2)

    SUB(v1,p2,r1)  dp2 = DOT(v1,N1);
    SUB(v1,q2,r1)  dq2 = DOT(v1,N1);
    SUB(v1,r2,r1)  dr2 = DOT(v1,N1);

    if (USEZERO(dp2)) dp2 = 0.0;
    if (USEZERO(dq2)) dq2 = 0.0;
    if (USEZERO(dr2)) dr2 = 0.0;

    if (dp2 * dq2 > 0.0 && dp2 * dr2 > 0.0) {
        return triangles_intersection_nop_plane_two; 
    }

    /* Permutation in a canonical form of T1's vertices. */

    if (dp1 > 0.0) {
        if (dq1 > 0.0) {
            TRI_TRI_INTER_3D(r1,p1,q1,p2,r2,q2,dp2,dr2,dq2)
        } else if (dr1 > 0.0) {
            TRI_TRI_INTER_3D(q1,r1,p1,p2,r2,q2,dp2,dr2,dq2)
        } else {
            TRI_TRI_INTER_3D(p1,q1,r1,p2,q2,r2,dp2,dq2,dr2)
        }
    } else if (dp1 < 0.0) {
        if (dq1 < 0.0) {
            TRI_TRI_INTER_3D(r1,p1,q1,p2,q2,r2,dp2,dq2,dr2)
        } else if (dr1 < 0.0) {
            TRI_TRI_INTER_3D(q1,r1,p1,p2,q2,r2,dp2,dq2,dr2)
        } else {
            TRI_TRI_INTER_3D(p1,q1,r1,p2,r2,q2,dp2,dr2,dq2)
        }
    } else if (dq1 < 0.0) {
        if (dr1 >= 0.0) {
            TRI_TRI_INTER_3D(q1,r1,p1,p2,r2,q2,dp2,dr2,dq2)
        } else {
            TRI_TRI_INTER_3D(p1,q1,r1,p2,q2,r2,dp2,dq2,dr2)
        }
    } else if (dq1 > 0.0) {
        if (dr1 > 0.0) {
            TRI_TRI_INTER_3D(p1,q1,r1,p2,r2,q2,dp2,dr2,dq2)
        } else {
            TRI_TRI_INTER_3D(q1,r1,p1,p2,q2,r2,dp2,dq2,dr2)
        }
    } else if (dr1 > 0.0) {
        TRI_TRI_INTER_3D(r1,p1,q1,p2,q2,r2,dp2,dq2,dr2)
    } else if (dr1 < 0.0) {
        TRI_TRI_INTER_3D(r1,p1,q1,p2,r2,q2,dp2,dr2,dq2)
    } else {
        return triangles_are_coplanar_gd(p1,q1,r1,p2,q2,r2,N1,epsilon) \
            ? triangles_intersection_nop_coplanar \
            : triangles_intersection_yes_coplanar; \
    }
}

/* Two dimensional Triangle-Triangle Overlap Test */

# define ORIENT_2D(a, b, c) ((a[0] - c[0]) * (b[1] - c[1]) - (a[1] - c[1]) * (b[0] - c[0]))

# define INTERSECTION_TEST_VERTEX(P1,Q1,R1,P2,Q2,R2) { \
    if (ORIENT_2D(R2,P2,Q1) >= 0.0) { \
        if (ORIENT_2D(R2,Q2,Q1) <= 0.0) { \
            if (ORIENT_2D(P1,P2,Q1) > 0.0) { \
                if (ORIENT_2D(P1,Q2,Q1) <= 0.0) { \
                    return 1; \
                } else { \
                    return 0; \
                } \
            } else if (ORIENT_2D(P1,P2,R1) >= 0.0) { \
                if (ORIENT_2D(Q1,R1,P2) >= 0.0) { \
                    return 1; \
                } else { \
                    return 0; \
                } \
            } else { \
                return 0; \
            } \
        } else if (ORIENT_2D(P1,Q2,Q1) <= 0.0) { \
            if (ORIENT_2D(R2,Q2,R1) <= 0.0) { \
                if (ORIENT_2D(Q1,R1,Q2) >= 0.0) { \
                    return 1; \
                } else { \
                    return 0; \
                } \
            } else { \
                return 0; \
            } \
        } else { \
            return 0; \
        } \
    } else if (ORIENT_2D(R2,P2,R1) >= 0.0) { \
        if (ORIENT_2D(Q1,R1,R2) >= 0.0) { \
            if (ORIENT_2D(P1,P2,R1) >= 0.0) { \
                return 1; \
            } else { \
                return 0; \
            } \
        } else if (ORIENT_2D(Q1,R1,Q2) >= 0.0) { \
            if (ORIENT_2D(R2,R1,Q2) >= 0.0) { \
                return 1; \
            } else { \
                return 0; \
            } \
        } else { \
              return 0; \
        } \
    } else { \
        return 0; \
    } \
}

# define INTERSECTION_TEST_EDGE(P1,Q1,R1,P2,Q2,R2) { \
    if (ORIENT_2D(R2,P2,Q1) >= 0.0) { \
        if (ORIENT_2D(P1,P2,Q1) >= 0.0) { \
            if (ORIENT_2D(P1,Q1,R2) >= 0.0) { \
                return 1; \
            } else { \
                return 0; \
            } \
        } else if (ORIENT_2D(Q1,R1,P2) >= 0.0) { \
            if (ORIENT_2D(R1,P1,P2) >= 0.0) { \
                return 1; \
            } else { \
                return 0; \
            } \
        } else { \
            return 0; \
        } \
    } else if (ORIENT_2D(R2,P2,R1) >= 0.0) { \
        if (ORIENT_2D(P1,P2,R1) >= 0.0) { \
            if (ORIENT_2D(P1,R1,R2) >= 0.0) { \
                return 1; \
            } else if (ORIENT_2D(Q1,R1,R2) >= 0.0) { \
                return 1; \
            } else { \
                return 0; \
            } \
        } else { \
            return 0; \
        } \
    } else { \
        return 0; \
    } \
}

static int triangles_intersection_2d(
    triangles_two p1,
    triangles_two q1,
    triangles_two r1,
    triangles_two p2,
    triangles_two q2,
    triangles_two r2,
    double        epsilon
) {
    if (ORIENT_2D(p2,q2,p1) >= 0.0) {
        if (ORIENT_2D(q2,r2,p1) >= 0.0) {
            if (ORIENT_2D(r2,p2,p1) >= 0.0) {
                return 1;
            } else {
                INTERSECTION_TEST_EDGE(p1,q1,r1,p2,q2,r2)
            }
        } else {
            if (ORIENT_2D(r2,p2,p1) >= 0.0) {
                INTERSECTION_TEST_EDGE(p1,q1,r1,r2,p2,q2)
            } else {
                INTERSECTION_TEST_VERTEX(p1,q1,r1,p2,q2,r2)
            }
        }
    } else {
        if (ORIENT_2D(q2,r2,p1) >= 0.0) {
            if (ORIENT_2D(r2,p2,p1) >= 0.0) {
                INTERSECTION_TEST_EDGE(p1,q1,r1,q2,r2,p2)
            } else {
                INTERSECTION_TEST_VERTEX(p1,q1,r1,q2,r2,p2)
            }
        } else {
            INTERSECTION_TEST_VERTEX(p1,q1,r1,r2,p2,q2)
        }
    }
}

int triangles_intersect_two_gd(
    triangles_two p1,
    triangles_two q1,
    triangles_two r1,
    triangles_two p2,
    triangles_two q2,
    triangles_two r2,
    double        epsilon
) {
    if (ORIENT_2D(p1,q1,r1) < 0.0) {
        return ORIENT_2D(p2,q2,r2) < 0.0
            ? triangles_intersection_2d(p1,r1,q1,p2,r2,q2,epsilon)
            : triangles_intersection_2d(p1,r1,q1,p2,q2,r2,epsilon);
    } else {
        return ORIENT_2D(p2,q2,r2) < 0.0
            ? triangles_intersection_2d(p1,q1,r1,p2,r2,q2,epsilon)
            : triangles_intersection_2d(p1,q1,r1,p2,q2,r2,epsilon);
    }
}
