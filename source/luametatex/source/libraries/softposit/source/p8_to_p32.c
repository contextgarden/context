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

posit32_t p8_to_p32( posit8_t pA ) {


	union ui8_p8 uA;
	union ui32_p32 uZ;
	uint_fast8_t uiA, tmp;
	uint_fast32_t exp_frac32A=0, regime;
	bool sign, regSA;
	int_fast8_t kA=0, regA;


	uA.p = pA;
	uiA = uA.ui;

	if (uiA==0x80 || uiA==0 ){
		uZ.ui = (uint32_t)uiA<<24;
		return uZ.p;
	}

	sign = signP8UI( uiA );

	if (sign) uiA = -uiA & 0xFF;
	regSA = signregP8UI(uiA);

	tmp = (uiA<<2) & 0xFF;
	if (regSA){
		while (tmp>>7){
			kA++;
			tmp= (tmp<<1) & 0xFF;
		}
	}
	else{
		kA=-1;
		while (!(tmp>>7)){
			kA--;
			tmp= (tmp<<1) & 0xFF;
		}
		tmp&=0x7F;
	}
	exp_frac32A = tmp<<22;

	if(kA<0){
		regA = -kA;
		// Place exponent bits
		exp_frac32A |= ( ((regA&0x1)| ((regA+1)&0x2))<<29 );

		regA = (regA+3)>>2;
		if (regA==0) regA=1;
		regSA = 0;
		regime = 0x40000000>>regA;
	}
	else{
		exp_frac32A |= ( (kA&0x3) << 29 );

		regA = (kA+4)>>2;
		if (regA==0) regA=1;
		regSA=1;
		regime = 0x7FFFFFFF - (0x7FFFFFFF>>regA);
	}

	exp_frac32A =((uint_fast32_t)exp_frac32A) >> (regA+1); //2 because of sign and regime terminating bit

	uZ.ui = regime + exp_frac32A;

	if (sign) uZ.ui = -uZ.ui & 0xFFFFFFFF;

	return uZ.p;
}

