
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


posit16_t p16_mul( posit16_t pA, posit16_t pB ){

	union ui16_p16 uA, uB, uZ;
	uint_fast16_t uiA, uiB;
	uint_fast16_t regA, fracA, regime, tmp;
	bool signA, signB, signZ, regSA, regSB, bitNPlusOne=0, bitsMore=0, rcarry;
	int_fast8_t expA;
	int_fast8_t kA=0;
	uint_fast32_t frac32Z;

	uA.p = pA;
	uiA = uA.ui;
	uB.p = pB;
	uiB = uB.ui;


	//NaR or Zero
	if ( uiA==0x8000 || uiB==0x8000 ){
		uZ.ui = 0x8000;
		return uZ.p;
	}
	else if (uiA==0 || uiB==0){
		uZ.ui = 0;
		return uZ.p;
	}

	signA = signP16UI( uiA );
	signB = signP16UI( uiB );
	signZ = signA ^ signB;

	if(signA) uiA = (-uiA & 0xFFFF);
	if(signB) uiB = (-uiB & 0xFFFF);

	regSA = signregP16UI(uiA);
	regSB = signregP16UI(uiB);

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
	fracA = (0x4000 | tmp);

	tmp = (uiB<<2) & 0xFFFF;
	if (regSB){
		while (tmp>>15){
			kA++;
			tmp= (tmp<<1) & 0xFFFF;
		}
	}
	else{
		kA--;
		while (!(tmp>>15)){
			kA--;
			tmp= (tmp<<1) & 0xFFFF;
		}
		tmp&=0x7FFF;
	}
	expA += tmp>>14;
	frac32Z = (uint_fast32_t) fracA * (0x4000 | tmp);

	if (expA>1){
		kA++;
		expA ^=0x2;
	}

	rcarry = frac32Z>>29;//3rd bit of frac32Z
	if (rcarry){
		if (expA) kA ++;
		expA^=1;
		frac32Z>>=1;
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
		//remove carry and rcarry bits and shift to correct position
		frac32Z = (frac32Z&0xFFFFFFF) >> (regA-1);
		fracA = (uint_fast16_t) (frac32Z>>16);

		if (regA!=14) bitNPlusOne |= (0x8000 & frac32Z) ;
		else if (fracA>0){
			fracA=0;
			bitsMore =1;
		}
		if (regA==14 && expA) bitNPlusOne = 1;

		//sign is always zero
		uZ.ui = packToP16UI(regime, regA, expA, fracA);
		//n+1 frac bit is 1. Need to check if another bit is 1 too if not round to even
		if (bitNPlusOne){
			if (0x7FFF & frac32Z) bitsMore=1;
			uZ.ui += (uZ.ui&1) | bitsMore;
		}
	}

	if (signZ) uZ.ui = -uZ.ui & 0xFFFF;
	return uZ.p;
}



