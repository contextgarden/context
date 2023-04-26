
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane) and John Gustafson.

Copyright 2017 2018 A*STAR.  All rights reserved.

This C source file was based on SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3d, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016 The Regents of the University of
California.  All Rights Reserved.

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

posit16_t i64_to_p16( int64_t iA ) {
	int_fast8_t k, log2 = 25;
	union ui16_p16 uZ;
	uint_fast16_t uiA;
	uint_fast64_t expA, mask = 0x0000000002000000, fracA;
	bool sign;

	if (iA < -134217728){ //-9223372036854775808 to -134217729 rounds to P32 value -268435456
		uZ.ui = 0x8001; //-maxpos
		return uZ.p;
	}

	sign = iA>>63;
	if (sign) iA = -iA;

	if( iA > 134217728 ) { //134217729 to 9223372036854775807 rounds to  P32 value 268435456
		uiA = 0x7FFF; //maxpos
	}
	else if ( iA > 0x0000000008000000 ) {
		uiA = 0x7FFF;
	}
	else if ( iA > 0x0000000002FFFFFF ){
		uiA = 0x7FFE;
	}
	else if ( iA < 2 ){
		uiA = (iA << 14);
	}
	else {
		fracA = iA;
		while ( !(fracA & mask) ) {
			log2--;
			fracA <<= 1;
		}
		k = log2 >> 1;
		expA = (log2 & 0x1) << (12 - k);
		fracA = fracA ^ mask;
		uiA = (0x7FFF ^ (0x3FFF >> k)) | expA | (fracA  >> (k + 13));
		mask = 0x1000 << k;
		if (mask & fracA) {
			if ( ((mask - 1) & fracA) | ((mask << 1) & fracA) ) uiA++;
		}
	}
	(sign) ? (uZ.ui = -uiA) : (uZ.ui = uiA);
	return uZ.p;

}
