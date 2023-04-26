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

posit8_t p16_to_p8( posit16_t pA ) {

	union ui16_p16 uA;
	union ui8_p8 uZ;
	uint_fast16_t uiA, tmp, regime;
	uint_fast16_t exp_frac16A=0;
	bool sign, regSA, bitsMore=0;
	int_fast8_t kA=0, regA;

	uA.p = pA;
	uiA = uA.ui;

	if (uiA==0x8000 || uiA==0 ){
		uZ.ui = (uiA>>8) &0xFF;
		return uZ.p;
	}

	sign = signP16UI( uiA );

	if (sign) uiA = -uiA & 0xFFFF;
	regSA = signregP16UI(uiA);

	tmp = (uiA<<2) & 0xFFFF;
	if (regSA){
		while (tmp>>15){
			kA++;
			tmp= (tmp<<1) & 0xFFFF;
		}
	}
	else{
		kA=-1;
		while (!(tmp>>15)){
			kA--;
			tmp= (tmp<<1) & 0xFFFF;
		}
		tmp&=0x7FFF;
	}

	if (kA<-3 || kA>=3){
		(kA<0) ? (uZ.ui=0x1):(uZ.ui= 0x7F);
	}
	else{
		//2nd bit exp
		exp_frac16A = tmp;
		if(kA<0){
			regA = ((-kA)<<1) - (exp_frac16A>>14);
			if (regA==0) regA=1;
			regSA = 0;
			regime = 0x40>>regA;
		}
		else{

			(kA==0)?(regA=1 + (exp_frac16A>>14)): (regA = ((kA+1)<<1) + (exp_frac16A>>14) -1);
			regSA=1;
			regime = 0x7F - (0x7F>>regA);
		}
		if (regA>5){
			uZ.ui = regime;
		}
		else{
			//int shift = regA+8;
			//exp_frac16A= ((exp_frac16A)&0x3FFF) >> shift; //first 2 bits already empty (for sign and regime terminating bit)
			uZ.ui = regime + ( ((exp_frac16A)&0x3FFF)>>(regA+8) );

		}

	}

	if ( exp_frac16A & (0x80<<regA) ){
		bitsMore = exp_frac16A & (0xFFFF>>(9-regA));
		uZ.ui += (uZ.ui&1) | bitsMore;

	}
	if (sign) uZ.ui = -uZ.ui & 0xFF;

	return uZ.p;
}

