/*
    See license.txt in the root of this project.
*/

# ifndef LMT_UTILITIES_ARITHMETIC_H
# define LMT_UTILITIES_ARITHMETIC_H

/* The |fabs| macro is used in mp. */

/*tex

There has always be much attention on accuracy in \TEX, especially in the perspective of portability. 
Keep in mind that \TEX\ was written when there was no IEEE floating point defined so all happens in 
16.16, or actually in 14.16 precission. We could actually consider going 16.16 if we use long integers 
in some places but it needs some checking first. We could just accept wrapping around as that already
happens in some places anyway (not all dimension calculation are checked).

In \LUATEX\ and \LUAMETATEX\ we have the \LUA\ engine and that one was exclusively using doubles till 
5.3 when it went for a more hybrid approach. Because we go a lot between \TEX\ and \LUA\ (in \CONTEXT) 
that had some consequences and rounding happens all over the place. It is also for that reason that 
we now use doubles and rounding in some more places in the \TEX\ part: it is more consistent with what 
happens at the \LUA\ end. And, because IEEE is common now, we are (afaiks) portable enough. 

We don't use round but lround as that one rounds away from zero. In a few places we use llround. Also 
in some places we clip to the official maxima but not always. 

*/


/*
# undef abs
# undef fabs

# define abs(x)    ((int)(x) >= 0 ? (int)(x) : (int)-(x))
# define fabs(x)   ((x) >= 0.0 ? (x) : -(x))
*/

# define odd(x)    ((x) & 1)

# define lfloor(x) ( (lua_Integer)(floor((double)(x))) )
# define tfloor(x) ( (size_t)     (floor((double)(x))) )
# define ifloor(x) ( (int)        (floor((double)(x))) )

//define lround(x) ( ((double) x >= 0.0) ? (lua_Integer) ((double) x + 0.5) : (lua_Integer) ((double) x - 0.5) )
//define tround(x) ( ((double) x >= 0.0) ? (size_t)      ((double) x + 0.5) : (size_t)      ((double) x - 0.5) )
//define iround(x) ( ((double) x >= 0.0) ? (int)         ((double) x + 0.5) : (int)         ((double) x - 0.5) )
//define sround(x) ( ((double) x >= 0.0) ? (int)         ((double) x + 0.5) : (int)         ((double) x - 0.5) )

//define lround(x) ( ((double) x >= 0.0) ? (lua_Integer) ((double) x + 0.5) : (lua_Integer) ((double) x - 0.5) )
//define tround(x) ( ((double) x >= 0.0) ? (size_t)      ((double) x + 0.5) : (size_t)      ((double) x - 0.5) )
//define iround(x) ( (int) lround((double) x) )

//define zround(r) ((r>2147483647.0) ? 2147483647 : ((r<-2147483647.0) ? -2147483647 : ((r >= 0.0) ? (int)(r + 0.5) : ((int)(r-0.5)))))
//define zround(r) ((r>2147483647.0) ? 2147483647 : ((r<-2147483647.0) ? -2147483647 : (int) lround(r)))

# define scaledround(x)  ((scaled) lround((double) (x)))
# define longlonground   llround
# define clippedround(r) ((r>2147483647.0) ? 2147483647 : ((r<-2147483647.0) ? -2147483647 : (int) lround(r)))
# define glueround(x)    clippedround((double) (x))

# endif
