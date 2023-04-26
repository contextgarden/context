
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane) and John Gustafson.

Copyright 2017, 2018 A*STAR.  All rights reserved.

This C source file was based on SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3d, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017 The Regents of the
University of California.  All rights reserved.

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

int_fast32_t p16_to_i32( posit16_t pA ){
	union ui16_p16 uA;
	int_fast32_t mask, iZ, tmp;
	uint_fast16_t scale = 0, uiA;
	bool bitLast, bitNPlusOne, sign;

	uA.p = pA;
	uiA = uA.ui;                             // Copy of the input.
	//NaR
	if (uiA==0x8000) return 0;

	sign = (uiA > 0x8000);                   // sign is True if pA > NaR.
	if (sign) uiA = -uiA & 0xFFFF;           // A is now |A|.

	if (uiA <= 0x3000) {                     // 0 <= |pA| <= 1/2 rounds to zero.
		return 0;
	}
	else if (uiA < 0x4800) {                 // 1/2 < x < 3/2 rounds to 1.
		iZ = 1;
	}
	else if (uiA <= 0x5400) {                // 3/2 <= x <= 5/2 rounds to 2.
		iZ = 2;
	}
	else {                                   // Decode the posit, left-justifying as we go.
		uiA -= 0x4000;                       // Strip off first regime bit (which is a 1).
		while (0x2000 & uiA) {               // Increment scale by 2 for each regime sign bit.
			scale += 2;                      // Regime sign bit is always 1 in this range.
			uiA = (uiA - 0x2000) << 1;       // Remove the bit; line up the next regime bit.
		}
		uiA <<= 1;                           // Skip over termination bit, which is 0.
		if (0x2000 & uiA) scale++;           // If exponent is 1, increment the scale.
		iZ = ((uint32_t)uiA | 0x2000) << 17;         // Left-justify fraction in 32-bit result (one left bit padding)
		mask = 0x40000000 >> scale;          // Point to the last bit of the integer part.

		bitLast = (iZ & mask);               // Extract the bit, without shifting it.
		mask >>= 1;
		tmp = (iZ & mask);
		bitNPlusOne = tmp;                   // "True" if nonzero.
		iZ ^= tmp;                           // Erase the bit, if it was set.
		tmp = iZ & (mask - 1);               // tmp has any remaining bits. // This is bitsMore
		iZ ^= tmp;                           // Erase those bits, if any were set.

		if (bitNPlusOne) {                   // logic for round to nearest, tie to even
			if (bitLast | tmp) iZ += (mask << 1);
		}

		iZ = (uint32_t)iZ >> (30 - scale);             // Right-justify the integer.
	}

	if (sign) iZ = -iZ;                      // Apply the sign of the input.
	return iZ;
}

