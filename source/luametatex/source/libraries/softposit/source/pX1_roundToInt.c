
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

posit_1_t pX1_roundToInt( posit_1_t pA, int x ){
	union ui32_pX1 uA;
	uint_fast32_t mask = 0x20000000, scale=0, tmp=0, uiA, uiZ;
	bool bitLast, bitNPlusOne, sign;

	uA.p = pA;
	uiA = uA.ui;
	sign = uiA>>31;

	// sign is True if pA > NaR.
	if (sign) uiA = -uiA & 0xFFFFFFFF;           // A is now |A|.
	if (uiA <= 0x30000000) {                     // 0 <= |pA| <= 1/2 rounds to zero.
		uA.ui = 0;
		return uA.p;
	}
	else if (uiA < 0x48000000) {                 // 1/2 < x < 3/2 rounds to 1.
		uA.ui = 0x40000000;
	}
	else if (uiA <= 0x54000000) {                // 3/2 <= x <= 5/2 rounds to 2.
		uA.ui = 0x50000000;
	}
	else if (uiA >= 0x7FE80000) {                 // If |A| is 0x7FE800000 (4194304) (posit is pure integer value), leave it unchanged.
		if (x>8) return uA.p;                           // This also takes care of the NaR case, 0x80000000.
		else{
			bitNPlusOne=((uint32_t)0x80000000>>x) & uiA;
			tmp = ((uint32_t)0x7FFFFFFF>>x)& uiA; //bitsMore
			bitLast = ((uint32_t)0x80000000>>(x-1)) & uiA;
			if (bitNPlusOne)
				if (bitLast | tmp) uiA += bitLast;
			uA.ui = uiA;
		}
	}
	else {                                   // 34% of the cases, we have to decode the posit.

		while (mask & uiA) {
			scale += 2;
			mask >>= 1;
		}
		mask >>= 1;
		if (mask & uiA) scale++;

		mask >>= scale;

		//the rest of the bits
		bitLast = (uiA & mask);
		mask >>= 1;
		tmp = (uiA & mask);
		bitNPlusOne = tmp;
		uiA ^= tmp;                            // Erase the bit, if it was set.
		tmp = uiA & (mask - 1);                // this is actually bitsMore

		uiA ^= tmp;    

		if (bitNPlusOne) {
			if (bitLast | tmp) uiA += (mask << 1);
		}
		uA.ui = uiA;


	}
	if (sign) uA.ui = -uA.ui & 0xFFFFFFFF;
	return uA.p;


}

