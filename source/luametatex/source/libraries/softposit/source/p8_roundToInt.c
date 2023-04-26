
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

posit8_t p8_roundToInt( posit8_t pA ) {

	union ui8_p8 uA;
	uint_fast8_t mask = 0x20, scale=0, tmp=0, uiA;
	bool bitLast, bitNPlusOne, sign;

	uA.p = pA;
	uiA = uA.ui;
	sign = (uiA > 0x80);

	// sign is True if pA > NaR.
	if (sign) uiA = -uiA & 0xFF;
	if (uiA <= 0x20) {                     // 0 <= |pA| <= 1/2 rounds to zero.
		uA.ui = 0;
		return uA.p;
	}
	else if (uiA < 0x50) {                 // 1/2 < x < 3/2 rounds to 1.
		uA.ui = 0x40;
	}
	else if (uiA <= 0x64) {                // 3/2 <= x <= 5/2 rounds to 2.
		uA.ui = 0x60;
	}
	else if (uiA >= 0x78) {                 // If |A| is 8 or greater, leave it unchanged.
		return uA.p;                           // This also takes care of the NaR case, 0x80.
	}
	else {
		while (mask & uiA) {
			scale += 1;
			mask >>= 1;
		}

		mask >>= scale;
		bitLast = (uiA & mask);

		mask >>= 1;
		tmp = (uiA & mask);
		bitNPlusOne = tmp;
		uiA ^= tmp;
		tmp = uiA & (mask - 1);     //bitsMore
		uiA ^= tmp;

		if (bitNPlusOne) {
			if (bitLast | tmp) uiA += (mask << 1);
		}
		uA.ui = uiA;
	}
	if (sign) uA.ui = -uA.ui & 0xFF;
	return uA.p;

}

