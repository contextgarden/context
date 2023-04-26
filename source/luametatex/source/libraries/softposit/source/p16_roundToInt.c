
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


posit16_t p16_roundToInt( posit16_t pA ) {

	union ui16_p16 uA;
	uint_fast16_t mask = 0x2000, scale=0, tmp=0, uiA;
	bool bitLast, bitNPlusOne, sign;

	uA.p = pA;
	uiA = uA.ui;                             // Copy of the input.
	sign = (uiA > 0x8000);

	// sign is True if pA > NaR.
	if (sign) uiA = -uiA & 0xFFFF;           // A is now |A|.
	if (uiA <= 0x3000) {                     // 0 <= |pA| <= 1/2 rounds to zero.
		uA.ui = 0;
		return uA.p;
	}
	else if (uiA < 0x4800) {                 // 1/2 < x < 3/2 rounds to 1.
		uA.ui = 0x4000;
	}
	else if (uiA <= 0x5400) {                // 3/2 <= x <= 5/2 rounds to 2.
		uA.ui = 0x5000;
	}
	else if (uiA >= 0x7C00) {                 // If |A| is 256 or greater, leave it unchanged.
		return uA.p;                           // This also takes care of the NaR case, 0x8000.
	}
	else {                                   // 34% of the cases, we have to decode the posit.
		while (mask & uiA) {                   // Increment scale by 2 for each regime sign bit.
			scale += 2;                          // Regime sign bit is always 1 in this range.
			mask >>= 1;                          // Move the mask right, to the next bit.
		}
		mask >>= 1;                            // Skip over termination bit.
		if (mask & uiA) scale++;               // If exponent is 1, increment the scale.

		mask >>= scale;                  	// Point to the last bit of the integer part.
		bitLast = (uiA & mask);				// Extract the bit, without shifting it.

		mask >>= 1;
		tmp = (uiA & mask);
		bitNPlusOne = tmp;                       // "True" if nonzero.
		uiA ^= tmp;                            // Erase the bit, if it was set.
		tmp = uiA & (mask - 1);                // tmp has any remaining bits.
		uiA ^= tmp;                            // Erase those bits, if any were set.

		if (bitNPlusOne) {                       // logic for round to nearest, tie to even
			if (bitLast | tmp) uiA += (mask << 1);
		}
		uA.ui = uiA;
	}
	if (sign) uA.ui = -uA.ui & 0xFFFF;       // Apply the sign of Z.
	return uA.p;

}

