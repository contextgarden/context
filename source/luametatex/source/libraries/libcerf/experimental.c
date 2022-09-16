/******************************************************************************/
/*  Experimental code                                                         */
/******************************************************************************/

/*
    Compute w_of_z via Fourier integration using Ooura-Mori transform.
    Agreement with Johnson's code usually < 1E-15, so far always < 1E-13.
    Todo:
    - sign for negative x or y
    - determine application limits
    - more systematical comparison with Johnson's code
    - comparison with Abrarov&Quine
 */

#define max_iter_int 10
#define num_range 5
#define PI           3.14159265358979323846L  /* pi */
#define SQR(x) ((x)*(x))
#include <errno.h>

double cerf_experimental_integration( int kind, double x, double y )
// kind: 0 cos, 1 sin transform (precomputing arrays[2] depend on this)
{
    // unused parameters
    static int mu = 0;
    int intgr_debug = 0;
    static double intgr_delta=2.2e-16, intgr_eps=5.5e-20;

    if( x<0 || y<0 ) {
        fprintf( stderr, "negative arguments not yet implemented\n" );
        exit( EDOM );
    }

    double w = sqrt(2)*x;
    double gamma = sqrt(2)*y;

    int iter;
    int kaux;
    int isig;
    int N;
    int j;               // range
    long double S=0;     // trapezoid sum
    long double S_last;  // - in last iteration
    long double s;       // term contributing to S
    long double T;       // sum of abs(s)
    // precomputed coefficients
    static int firstCall=1;
    static int iterDone[2][num_range]; // Nm,Np,ak,bk are precomputed up to this
    static int Nm[num_range][max_iter_int];
    static int Np[num_range][max_iter_int];
    static long double *ak[2][num_range][max_iter_int];
    static long double *bk[2][num_range][max_iter_int];
    // auxiliary for computing ak and bk
    long double u;
    long double e;
    long double tk;
    long double chi;
    long double dchi;
    long double h;
    long double k;
    long double f;
    long double ahk;
    long double chk;
    long double dhk;
    double p;
    double q;
    const double Smin=2e-20; // to assess worst truncation error

    // dynamic initialization upon first call
    if ( firstCall ) {
        for ( j=0; j<num_range; ++ j ) {
            iterDone[0][j] = -1;
            iterDone[1][j] = -1;
        }
        firstCall = 0;
    }

    // determine range, set p,q
    j=1; p=1.4; q=0.6;

    // iterative integration
    if( intgr_debug & 4 )
        N = 100;
    else
        N = 40;
    for ( iter=0; iter<max_iter_int; ++iter ) {
        // static initialisation of Nm, Np, ak, bk for given 'iter'
        if ( iter>iterDone[kind][j] ) {
            if ( N>1e6 )
                return -3; // integral limits overflow
            Nm[j][iter] = N;
            Np[j][iter] = N;
            if ( !( ak[kind][j][iter]=malloc((sizeof(long double))*
                                         (Nm[j][iter]+1+Np[j][iter])) ) ||
                !( bk[kind][j][iter]=malloc((sizeof(long double))*
                                         (Nm[j][iter]+1+Np[j][iter])) ) ) {
                fprintf( stderr, "Workspace allocation failed\n" );
                exit( ENOMEM );
            }
            h = logl( logl( 42*N/intgr_delta/Smin ) / p ) / N; // 42=(pi+1)*10
            isig=1-2*(Nm[j][iter]&1);
            for ( kaux=-Nm[j][iter]; kaux<=Np[j][iter]; ++kaux ) {
                k = kaux;
                if( !kind )
                    k -= 0.5;
                u = k*h;
                chi  = 2*p*sinhl(u) + 2*q*u;
                dchi = 2*p*coshl(u) + 2*q;
                if ( u==0 ) {
                    if ( k!=0 )
                        return -4; // integration variable underflow
                    // special treatment to bridge singularity at u=0
                    ahk = PI/h/dchi;
                    dhk = 0.5;
                    chk = sin( ahk );
                } else {
                    if ( -chi>DBL_MAX_EXP/2 )
                        return -5; // integral transformation overflow
                    e = expl( -chi );
                    ahk = PI/h * u/(1-e);
                    dhk = 1/(1-e) - u*e*dchi/SQR(1-e);
                    chk = e>1 ?
                        ( kind ? sinl( PI*k/(1-e) ) : cosl( PI*k/(1-e) ) ) :
                        isig * sinl( PI*k*e/(1-e) );
                }
                ak[kind][j][iter][kaux+Nm[j][iter]] = ahk;
                bk[kind][j][iter][kaux+Nm[j][iter]] = dhk * chk;
                isig = -isig;
            }
            iterDone[kind][j] = iter;
        }
        // integrate according to trapezoidal rule
        S_last = S;
        S = 0;
        T = 0;
        for ( kaux=-Nm[j][iter]; kaux<=Np[j][iter]; ++kaux ) {
            tk = ak[kind][j][iter][kaux+Nm[j][iter]] / w;
            f = expl(-tk*gamma-SQR(tk)/2); // Fourier kernel
            if ( mu )
                f /= tk; // TODO
            s = bk[kind][j][iter][kaux+Nm[j][iter]] * f;
            S += s;
            T += fabsl(s);
            if( intgr_debug & 2 )
                printf( "%2i %6i %12.4Lg %12.4Lg"
                        " %12.4Lg %12.4Lg %12.4Lg %12.4Lg\n",
                        iter, kaux, ak[kind][j][iter][kaux+Nm[j][iter]],
                        bk[kind][j][iter][kaux+Nm[j][iter]], f, s, S, T );
        }
        if( intgr_debug & 1 )
            printf( "%23.17Le  %23.17Le\n", S, T );
        // intgr_num_of_terms += Np[j][iter]-(-Nm[j][iter])+1;
        // termination criteria
        if      ( intgr_debug & 4 )
            return -1; // we want to inspect just one sum
        else if ( S < 0 )
            return -6; // cancelling terms lead to negative S
        else if ( intgr_eps*T > intgr_delta*fabs(S) )
            return -2; // cancellation
        else if ( iter && fabs(S-S_last) + intgr_eps*T < intgr_delta*fabs(S) )
            return S*sqrt(2*PI)/w; // success
            // factor 2 from int_-infty^+infty = 2 * int_0^+infty
            // factor pi/w from formula 48 in kww paper
            // factor 1/sqrt(2*pi) from Gaussian
        N *= 2; // retry with more points
    }
    return -9; // not converged
}

double cerf_experimental_imw( double x, double y )
{
    return cerf_experimental_integration( 1, x, y );
}

double cerf_experimental_rew( double x, double y )
{
    return cerf_experimental_integration( 0, x, y );
}
