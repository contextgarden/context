
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

int_fast64_t p16_to_i64( posit16_t pA ){
	union ui16_p16 uA;
	int_fast64_t mask, tmp, iZ;
	uint_fast16_t scale = 0, uiA;
	bool sign, bitLast, bitNPlusOne;

	uA.p = pA;
	uiA = uA.ui;

	// NaR
	if (uiA==0x8000) return 0;

	sign = uiA>>15;
	if (sign) uiA = -uiA & 0xFFFF;

	if (uiA <= 0x3000)
		return 0;
	else if (uiA < 0x4800)
		iZ = 1;
	else if (uiA <= 0x5400)
		iZ = 2;
	else{

		uiA -= 0x4000;

		while (0x2000 & uiA) {
			scale += 2;
			uiA = (uiA - 0x2000) << 1;
		}
		uiA <<= 1;
		if (0x2000 & uiA) scale++;
		iZ = ((uint64_t)uiA | 0x2000) << 49;

		mask = 0x4000000000000000 >> scale;

		bitLast = (iZ & mask);
		mask >>= 1;
		tmp = (iZ & mask);
		bitNPlusOne = tmp;
		iZ ^= tmp;
		tmp = iZ & (mask - 1);  // bitsMore
		iZ ^= tmp;

		if (bitNPlusOne)
			if (bitLast | tmp) iZ += (mask << 1);

		iZ = (uint64_t)iZ >> (62 - scale);

	}
	if (sign) iZ = -iZ;
	return iZ;

}

