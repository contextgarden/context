
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane) and John Gustafson.

Copyright 2017 2018 A*STAR.  All rights reserved.

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

uint_fast64_t p8_to_ui64( posit8_t pA ) {

	union ui8_p8 uA;
	uint_fast64_t mask, iZ, tmp;
	uint_fast8_t scale = 0, uiA;
	bool bitLast, bitNPlusOne;

	uA.p = pA;
	uiA = uA.ui;                             // Copy of the input.
	//NaR
	//if (uiA==0x80) return 0;
	if (uiA>=0x80) return 0; 	//negative

	if (uiA <= 0x20) {                     // 0 <= |pA| <= 1/2 rounds to zero.
		return 0;
	}
	else if (uiA < 0x50) {                 // 1/2 < x < 3/2 rounds to 1.
		iZ = 1;
	}
	else {                                   // Decode the posit, left-justifying as we go.

		uiA -= 0x40;                       // Strip off first regime bit (which is a 1).
		while (0x20 & uiA) {               // Increment scale by 1 for each regime sign bit.
			scale ++;                      // Regime sign bit is always 1 in this range.
			uiA = (uiA - 0x20) << 1;       // Remove the bit; line up the next regime bit.
		}
		uiA <<= 1;                           // Skip over termination bit, which is 0.

		iZ = ((uint64_t)uiA | 0x40) << 55;         // Left-justify fraction in 32-bit result (one left bit padding)

		mask = 0x2000000000000000 >> scale;          // Point to the last bit of the integer part.

		bitLast = (iZ & mask);               // Extract the bit, without shifting it.
		mask >>= 1;
		tmp = (iZ & mask);
		bitNPlusOne = tmp;                   // "True" if nonzero.
		iZ ^= tmp;                           // Erase the bit, if it was set.
		tmp = iZ & (mask - 1);               // tmp has any remaining bits. // This is bitsMore
		iZ ^= tmp;							// Erase those bits, if any were set.

	if (bitNPlusOne) {                   // logic for round to nearest, tie to even
			if (bitLast | tmp) iZ +=  (mask<<1) ;
		}
		iZ = (uint64_t)iZ >> (61 - scale);    // Right-justify the integer.
	}

	return iZ;

}

