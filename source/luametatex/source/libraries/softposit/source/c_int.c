
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

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

int_fast64_t p8_int( posit8_t pA ) {

	union ui8_p8 uA;
	int_fast64_t iZ;
	uint_fast8_t scale = 0, uiA;
	bool sign;

	uA.p = pA;
	uiA = uA.ui;
	//NaR
	if (uiA==0x80) return 0x8000000000000000LL;

	sign = uiA>>7;
	if (sign) uiA = -uiA & 0xFF;

	if (uiA < 0x40) return 0;
	else if (uiA < 0x60)  iZ = 1;
	else {
		uiA -= 0x40;
		while (0x20 & uiA) {
			scale ++;
			uiA = (uiA - 0x20) << 1;
		}
		uiA <<= 1;
		iZ = ((uint64_t)uiA | 0x40)  >> (6 - scale);
	}

	if (sign) iZ = -iZ;
	return iZ;

}

int_fast64_t p16_int( posit16_t pA ){
	union ui16_p16 uA;
	int_fast64_t iZ;
	uint_fast16_t scale = 0, uiA;
	bool sign;

	uA.p = pA;
	uiA = uA.ui;

	// NaR
	if (uiA==0x8000) return 0x8000000000000000LL;

	sign = uiA>>15;
	if (sign) uiA = -uiA & 0xFFFF;

	if (uiA < 0x4000) return 0;
	else if (uiA < 0x5000) iZ = 1;
	else if (uiA < 0x5800) iZ = 2;
	else{
		uiA -= 0x4000;
		while (0x2000 & uiA) {
			scale += 2;
			uiA = (uiA - 0x2000) << 1;
		}
		uiA <<= 1;
		if (0x2000 & uiA) scale++;
		iZ = ((uint64_t)uiA | 0x2000) >> (13 - scale);

	}
	if (sign) iZ = -iZ;
	return iZ;

}


int64_t p32_int( posit32_t pA ){
 	union ui32_p32 uA;
    int_fast64_t iZ;
    uint_fast32_t scale = 0, uiA;
    bool sign;

	uA.p = pA;
	uiA = uA.ui;

	if (uiA==0x80000000) return 0x8000000000000000;

	sign = uiA>>31;
	if (sign) uiA = -uiA & 0xFFFFFFFF;

	if (uiA < 0x40000000)  return 0;
	else if (uiA < 0x48000000) iZ = 1;
	else if (uiA < 0x4C000000) iZ = 2;
	else if(uiA>0x7FFFAFFF) iZ=  0x7FFFFFFFFFFFFFFF;
	else{
		uiA -= 0x40000000;
		while (0x20000000 & uiA) {
			scale += 4;
			uiA = (uiA - 0x20000000) << 1;
		}
		uiA <<= 1;  								// Skip over termination bit, which is 0.
		if (0x20000000 & uiA) scale+=2;          	// If first exponent bit is 1, increment the scale.
		if (0x10000000 & uiA) scale++;
		iZ = ((uiA | 0x10000000ULL)&0x1FFFFFFFULL) << 34;	// Left-justify fraction in 32-bit result (one left bit padding)

		iZ = (scale<62) ? ((uiA | 0x10000000ULL)&0x1FFFFFFFULL) >> (28-scale):
				((uiA | 0x10000000ULL)&0x1FFFFFFFULL) << (scale-28);

	}

	if (sign) iZ = -iZ ;
	return iZ;
}

int64_t pX2_int( posit_2_t pA ){
	posit32_t p32 = {.v = pA.v};
	return p32_int(p32);

}

