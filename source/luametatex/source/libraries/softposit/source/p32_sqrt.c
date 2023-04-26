
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3d, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016 The Regents of the University of
California.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions, and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors may
    be used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/

#include "platform.h"
#include "internals.h"

extern const uint_fast16_t softposit_approxRecipSqrt0[];
extern const uint_fast16_t softposit_approxRecipSqrt1[];



posit32_t p32_sqrt( posit32_t pA ) {

    union ui32_p32 uA;
    uint_fast32_t index, r0, shift, fracA, expZ, expA;
    uint_fast32_t mask, uiA, uiZ;
    uint_fast64_t eSqrR0, fracZ, negRem, recipSqrt, shiftedFracZ, sigma0, sqrSigma0;
    int_fast32_t eps, shiftZ;

    uA.p = pA;
    uiA = uA.ui;

    // If NaR or a negative number, return NaR.
    if (uiA & 0x80000000) {
        uA.ui = 0x80000000;
        return uA.p;
    }
    // If the argument is zero, return zero.
    else if (!uiA) {
        return uA.p;
    }
    // Compute the square root; shiftZ is the power-of-2 scaling of the result.
    // Decode regime and exponent; scale the input to be in the range 1 to 4:
    if (uiA & 0x40000000) {
        shiftZ = -2;
        while (uiA & 0x40000000) {
            shiftZ += 2;
            uiA = (uiA << 1) & 0xFFFFFFFF;
        }
    } else {
        shiftZ = 0;
        while (!(uiA & 0x40000000)) {
            shiftZ -= 2;
            uiA = (uiA << 1) & 0xFFFFFFFF;
        }
    }

    uiA &= 0x3FFFFFFF;
    expA = (uiA >> 28);
    shiftZ += (expA >> 1);
    expA = (0x1 ^ (expA & 0x1));
    uiA &= 0x0FFFFFFF;
    fracA = (uiA | 0x10000000);

    // Use table look-up of first 4 bits for piecewise linear approx. of 1/sqrt:
    index = ((fracA >> 24) & 0xE) + expA;
    eps = ((fracA >> 9) & 0xFFFF);
    r0 = softposit_approxRecipSqrt0[index]
         - (((uint_fast32_t) softposit_approxRecipSqrt1[index] * eps) >> 20);

    // Use Newton-Raphson refinement to get 33 bits of accuracy for 1/sqrt:
    eSqrR0 = (uint_fast64_t) r0 * r0;
    if (!expA) eSqrR0 <<= 1;
    sigma0 = 0xFFFFFFFF & (0xFFFFFFFF ^ ((eSqrR0 * (uint64_t)fracA) >> 20));
    recipSqrt = ((uint_fast64_t) r0 << 20) + (((uint_fast64_t) r0 * sigma0) >> 21);

    sqrSigma0 = ((sigma0 * sigma0) >> 35);
    recipSqrt += ( ((  recipSqrt + (recipSqrt >> 2) - ((uint_fast64_t)r0 << 19)  ) * sqrSigma0) >> 46 );


    fracZ = (((uint_fast64_t) fracA) * recipSqrt) >> 31;
    if (expA) fracZ = (fracZ >> 1);

    // Find the exponent of Z and encode the regime bits.
    expZ = shiftZ & 0x3;
    if (shiftZ < 0) {
        shift = (-1 - shiftZ) >> 2;
        uiZ = 0x20000000 >> shift;
    } else {
        shift = shiftZ >> 2;
        uiZ = 0x7FFFFFFF - (0x3FFFFFFF >> shift);
    }

    // Trick for eliminating off-by-one cases that only uses one multiply:
    fracZ++;
    if (!(fracZ & 0xF)) {
        shiftedFracZ = fracZ >> 1;
        negRem = (shiftedFracZ * shiftedFracZ) & 0x1FFFFFFFF;
        if (negRem & 0x100000000) {
            fracZ |= 1;
        } else {
            if (negRem) fracZ--;
        }
    }
    // Strip off the hidden bit and round-to-nearest using last shift+5 bits.
    fracZ &= 0xFFFFFFFF;
    mask = (1 << (4 + shift));
    if (mask & fracZ) {
        if ( ((mask - 1) & fracZ) | ((mask << 1) & fracZ) ) fracZ += (mask << 1);
    }
    // Assemble the result and return it.
    uA.ui = uiZ | (expZ << (27 - shift)) | (fracZ >> (5 + shift));
    return uA.p;
}
