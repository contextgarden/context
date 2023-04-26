
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

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

posit32_t softposit_subMagsP32( uint_fast32_t uiA, uint_fast32_t uiB ) {

	uint_fast16_t regA, regB;
	uint_fast64_t frac64A=0, frac64B=0;
	uint_fast32_t fracA=0, regime, tmp;
	bool sign, regSA, regSB, ecarry=0, bitNPlusOne=0, bitsMore=0;
	int_fast8_t kA=0;
	int_fast32_t expA=0;
	int_fast16_t shiftRight;
	union ui32_p32 uZ;

	sign = signP32UI( uiA );
	if (sign)
		uiA = -uiA & 0xFFFFFFFF;
	else
		uiB = -uiB & 0xFFFFFFFF;

	if (uiA==uiB){ //essential, if not need special handling
		uZ.ui = 0;
		return uZ.p;
	}
	if ((int_fast32_t)uiA < (int_fast32_t)uiB){
		uiA ^= uiB;
		uiB ^= uiA;
		uiA ^= uiB;
		(sign) ? (sign = 0 ) : (sign=1); //A becomes B
	}
	regSA = signregP32UI( uiA );
	regSB = signregP32UI( uiB );

	tmp = (uiA<<2)&0xFFFFFFFF;
	if (regSA){
		while (tmp>>31){
			kA++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
	}
	else{
		kA=-1;
		while (!(tmp>>31)){
			kA--;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		tmp&=0x7FFFFFFF;
	}

	expA = tmp>>29; //to get 2 bits
	frac64A = ((0x40000000ULL | tmp<<1) & 0x7FFFFFFFULL) <<32;
	shiftRight = kA;


	tmp = (uiB<<2) & 0xFFFFFFFF;
	if (regSB){
		while (tmp>>31){
			shiftRight--;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}

	}
	else{
		shiftRight++;
		while (!(tmp>>31)){
			shiftRight++;
			tmp= (tmp<<1) & 0xFFFFFFFF;
		}
		tmp&=0x7FFFFFFF;

	}
	frac64B = ((0x40000000ULL | tmp<<1) & 0x7FFFFFFFULL) <<32;

	//This is 4kZ + expZ; (where kZ=kA-kB and expZ=expA-expB)
	shiftRight = (shiftRight<<2) + expA - (tmp>>29);
	if (shiftRight>63){
		uZ.ui = uiA;
		if (sign) uZ.ui = -uZ.ui & 0xFFFFFFFF;
		return uZ.p;
	}
	else
		(frac64B >>= shiftRight);

	frac64A -= frac64B;

	while((frac64A>>59)==0){
		kA--;
		frac64A<<=4;
	}
	ecarry = (0x4000000000000000 & frac64A);//(0x4000000000000000 & frac64A)>>62;
	while (!ecarry){
		if (expA==0){
			kA--;
			expA=3;
		}
		else
			expA--;
		frac64A<<=1;
		ecarry = (0x4000000000000000 & frac64A);
	}

	if(kA<0){
		regA = -kA;
		regSA = 0;
		regime = 0x40000000>>regA;
	}
	else{
		regA = kA+1;
		regSA=1;
		regime = 0x7FFFFFFF - (0x7FFFFFFF>>regA);
	}
	if(regA>30){
		//max or min pos. exp and frac does not matter.
		(regSA) ? (uZ.ui= 0x7FFFFFFF): (uZ.ui=0x1);
	}
	else{
		//remove hidden bits
		frac64A = (frac64A & 0x3FFFFFFFFFFFFFFF) >>(regA + 2) ; // 2 bits exp

		fracA = frac64A>>32;

		if (regA<=28){
			bitNPlusOne |= (0x80000000 & frac64A) ;
			expA <<= (28-regA);
		}
		else {
			if (regA==30){
				bitNPlusOne = expA&0x2;
				bitsMore = (expA&0x1);
				expA = 0;
			}
			else if (regA==29){
				bitNPlusOne = expA&0x1;
				expA>>=1;
			}
			if (fracA>0){
				fracA=0;
				bitsMore =1;
			}

		}

		uZ.ui = packToP32UI(regime, expA, fracA);
		//n+1 frac bit is 1. Need to check if another bit is 1 too if not round to even
		if (bitNPlusOne){
			if (0x7FFFFFFF & frac64A)bitsMore=1;
			uZ.ui += (uZ.ui&1) | bitsMore;
		}
	}
	if (sign) uZ.ui = -uZ.ui & 0xFFFFFFFF;
	return uZ.p;
}

