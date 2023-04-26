
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane) and John Gustafson.

Copyright 2017, 2018 A*STAR.  All rights reserved.

This C source file was based on SoftFloat IEEE Floating-Point Arithmetic
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

posit16_t p16_sqrt( posit16_t pA ) {

    union ui16_p16 uA;
    uint_fast16_t expA, fracA, index, r0, shift, sigma0, uiA, uiZ;
    uint_fast32_t eSqrR0, fracZ, negRem, recipSqrt, shiftedFracZ;
    int_fast16_t kZ;
    bool bitNPlusOne;

    uA.p = pA;
    uiA = uA.ui;

    // If sign bit is set, return NaR.
    if (uiA>>15) {
        uA.ui = 0x8000;
        return uA.p;
    }
    // If the argument is zero, return zero.
    if (uiA==0) {
        uA.ui = 0;
        return uA.p;
    }
    // Compute the square root. Here, kZ is the net power-of-2 scaling of the result.
    // Decode the regime and exponent bit; scale the input to be in the range 1 to 4:
	if (uiA >> 14) {
		kZ = -1;
		while (uiA & 0x4000) {
			kZ++;
			uiA= (uiA<<1) & 0xFFFF;
		}
	}
	else {
		kZ = 0;
		while (!(uiA & 0x4000)) {
			kZ--;
			uiA= (uiA<<1) & 0xFFFF;
		}

	}
	uiA &= 0x3fff;
	expA = 1 - (uiA >> 13);
	fracA = (uiA | 0x2000) >> 1;

	// Use table look-up of first four bits for piecewise linear approx. of 1/sqrt:
	index = ((fracA >> 8) & 0xE) + expA;

	r0 = softposit_approxRecipSqrt0[index]
		- (((uint_fast32_t) softposit_approxRecipSqrt1[index]
			* (fracA & 0x1FF)) >> 13);
	// Use Newton-Raphson refinement to get more accuracy for 1/sqrt:
	eSqrR0 = ((uint_fast32_t) r0 * r0) >> 1;

	if (expA) eSqrR0 >>= 1;
	sigma0 = 0xFFFF ^ (0xFFFF & (((uint64_t)eSqrR0 * (uint64_t)fracA) >> 18));//~(uint_fast16_t) ((eSqrR0 * fracA) >> 18);
	recipSqrt = ((uint_fast32_t) r0 << 2) + (((uint_fast32_t) r0 * sigma0) >> 23);

	// We need 17 bits of accuracy for posit16 square root approximation.
	// Multiplying 16 bits and 18 bits needs 64-bit scratch before the right shift:
	fracZ = (((uint_fast64_t) fracA) * recipSqrt) >> 13;

	// Figure out the regime and the resulting right shift of the fraction:
	if (kZ < 0) {
		shift = (-1 - kZ) >> 1;
		uiZ = 0x2000 >> shift;
	}
	else {
		shift = kZ >> 1;
		uiZ = 0x7fff - (0x7FFF >> (shift + 1));
	}
	// Set the exponent bit in the answer, if it is nonzero:
	if (kZ & 1) uiZ |= (0x1000 >> shift);

	// Right-shift fraction bits, accounting for 1 <= a < 2 versus 2 <= a < 4:
	fracZ = fracZ >> (expA + shift);

	// Trick for eliminating off-by-one cases that only uses one multiply:
	fracZ++;
	if (!(fracZ & 7)) {
		shiftedFracZ = fracZ >> 1;
		negRem = (shiftedFracZ * shiftedFracZ) & 0x3FFFF;
		if (negRem & 0x20000) {
			fracZ |= 1;
		} else {
			if (negRem) fracZ--;
		}
	}
	// Strip off the hidden bit and round-to-nearest using last 4 bits.
	fracZ -= (0x10000 >> shift);
	bitNPlusOne = (fracZ >> 3) & 1;
	if (bitNPlusOne) {
		if (((fracZ >> 4) & 1) | (fracZ & 7)) fracZ += 0x10;
	}
	// Assemble the result and return it.
	uA.ui = uiZ | (fracZ >> 4);
	return uA.p;

}
