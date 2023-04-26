
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

#ifdef SOFTPOSIT_EXACT
posit16_t softposit_subMagsP16( uint_fast16_t uiA, uint_fast16_t uiB, bool isExact){
#else
posit16_t softposit_subMagsP16( uint_fast16_t uiA, uint_fast16_t uiB ){
#endif
	uint_fast16_t regA;
	uint_fast32_t frac32A, frac32B;
	uint_fast16_t fracA=0, regime, tmp;
	bool sign=0, regSA, regSB, ecarry=0, bitNPlusOne=0, bitsMore=0;
	int_fast16_t shiftRight;
	int_fast8_t kA=0, expA;
    union ui16_p16 uZ;

    //Both uiA and uiB are actually the same signs if uiB inherits sign of sub
    //Make both positive
    sign = signP16UI( uiA );
    (sign)?(uiA = (-uiA & 0xFFFF)): (uiB = (-uiB & 0xFFFF));

    if (uiA==uiB){ //essential, if not need special handling
		uZ.ui = 0;
		return uZ.p;
	}
    if(uiA<uiB){
		uiA ^= uiB;
		uiB ^= uiA;
		uiA ^= uiB;
		(sign) ? (sign = 0 ) : (sign=1); //A becomes B
	}

    regSA = signregP16UI( uiA );
    regSB = signregP16UI( uiB );

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
	expA = tmp>>14;
	frac32A = (0x4000 | tmp) << 16;
	shiftRight = kA;

	tmp = (uiB<<2) & 0xFFFF;
	if (regSB){
		while (tmp>>15){
			shiftRight--;
			tmp= (tmp<<1) & 0xFFFF;
		}
	}
	else{
		shiftRight++;
		while (!(tmp>>15)){
			shiftRight++;
			tmp= (tmp<<1) & 0xFFFF;
		}
		tmp&=0x7FFF;
	}
	frac32B = (0x4000 | tmp) <<16;
	//This is 2kZ + expZ; (where kZ=kA-kB and expZ=expA-expB)

	shiftRight = (shiftRight<<1) + expA - (tmp>>14);

	if (shiftRight!=0){
		if (shiftRight>=29){
			uZ.ui = uiA;
			if (sign) uZ.ui = -uZ.ui & 0xFFFF;
			return uZ.p;
		}
		else
			frac32B >>= shiftRight;
	}

	frac32A -= frac32B;

	while((frac32A>>29)==0){
		kA--;
		frac32A<<=2;
	}
	ecarry = (0x40000000 & frac32A)>>30;
	if(!ecarry){
		if (expA==0) kA--;
		expA^=1;
		frac32A<<=1;
	}

	if(kA<0){
		regA = (-kA & 0xFFFF);
		regSA = 0;
		regime = 0x4000>>regA;
	}
	else{
		regA = kA+1;
		regSA=1;
		regime = 0x7FFF - (0x7FFF>>regA);
	}

	if(regA>14){
		//max or min pos. exp and frac does not matter.
		(regSA) ? (uZ.ui= 0x7FFF): (uZ.ui=0x1);
	}
	else{
		//remove hidden bits
		frac32A = (frac32A & 0x3FFFFFFF) >>(regA + 1) ;
		fracA = frac32A>>16;
		if (regA!=14) bitNPlusOne = (frac32A>>15) & 0x1;
		else if (frac32A>0){
			fracA=0;
			bitsMore =1;
		}
		if (regA==14 && expA) bitNPlusOne = 1;
		uZ.ui = packToP16UI(regime, regA, expA, fracA);
		if (bitNPlusOne){
			if ( frac32A&0x7FFF ) bitsMore=1;
			 //n+1 frac bit is 1. Need to check if another bit is 1 too if not round to even
			uZ.ui += (uZ.ui&1) | bitsMore;
		}
	}
	if (sign) uZ.ui = -uZ.ui & 0xFFFF;
	return uZ.p;

}

