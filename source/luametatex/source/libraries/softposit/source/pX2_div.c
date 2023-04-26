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

#include <stdlib.h>

#include "platform.h"
#include "internals.h"

posit_2_t pX2_div( posit_2_t pA, posit_2_t pB, int x ) {
    union ui32_pX2 uA, uB, uZ;
    int regA, regB;
    uint_fast32_t uiA, uiB, fracA, fracB, regime, tmp;
    bool signA, signB, signZ, regSA, regSB, bitNPlusOne=0, bitsMore=0, rcarry;
	int_fast8_t kA=0;
	int_fast32_t expA;
	uint_fast64_t frac64A, frac64Z, rem;
	lldiv_t divresult;

    if (x<2 || x>32){
    	uZ.ui = 0x80000000;
    	return uZ.p;
    }

	uA.p = pA;
	uiA = uA.ui;
	uB.p = pB;
	uiB = uB.ui;

	//Zero or infinity
	if ( uiA==0x80000000 || uiB==0x80000000 || uiB==0){
#ifdef SOFTPOSIT_EXACT
		uZ.ui.v = 0x80000000;
		uZ.ui.exact = 0;
#else
		uZ.ui = 0x80000000;
#endif
		return uZ.p;
	}
	else if (uiA==0){
#ifdef SOFTPOSIT_EXACT

		uZ.ui.v = 0;
		if ( (uiA==0 && uiA.ui.exact) || (uiB==0 && uiB.ui.exact) )
			uZ.ui.exact = 1;
		else
			uZ.ui.exact = 0;
#else
		uZ.ui = 0;
#endif
		return uZ.p;
	}

	signA = signP32UI( uiA );
	signB = signP32UI( uiB );
	signZ = signA ^ signB;
	if(signA) uiA = (-uiA & 0xFFFFFFFF);
	if(signB) uiB = (-uiB & 0xFFFFFFFF);
	regSA = signregP32UI(uiA);
	regSB = signregP32UI(uiB);

	if (x==2){
		uZ.ui = 0x40000000;
	}
	else{
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
		fracA = ((tmp<<1) | 0x40000000) & 0x7FFFFFFF;
		frac64A = (uint64_t) fracA << 30;

		tmp = (uiB<<2)&0xFFFFFFFF;
		if (regSB){
			while (tmp>>31){
				kA--;
				tmp= (tmp<<1) & 0xFFFFFFFF;
			}
		}
		else{
			kA++;
			while (!(tmp>>31)){
				kA++;
				tmp= (tmp<<1) & 0xFFFFFFFF;
			}
			tmp&=0x7FFFFFFF;
		}
		expA -= tmp>>29;
		fracB = ((tmp<<1) | 0x40000000) & 0x7FFFFFFF;

		divresult = lldiv (frac64A,(uint_fast64_t)fracB);
		frac64Z = divresult.quot;
		rem = divresult.rem;

		if (expA<0){
			expA+=4;
			kA--;
		}
		if (frac64Z!=0){
			rcarry = frac64Z >> 30; // this is the hidden bit (14th bit) , extreme right bit is bit 0
			if (!rcarry){
				if (expA==0){
					kA--;
					expA=3;
				}
				else
					expA--;
				frac64Z<<=1;
			}
		}
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
	if(regA>(x-2)){
		//max or min pos. exp and frac does not matter.
		uZ.ui=(regSA) ? (0x7FFFFFFF & ((int32_t)0x80000000>>(x-1)) ): (0x1 << (32-x));
	}
	else{
		//remove carry and rcarry bits and shift to correct position
		frac64Z &= 0x3FFFFFFF;
		fracA = (uint_fast32_t)frac64Z >> (regA+2);
		//regime length is smaller than length of posit
		if (regA<x){
			if (regA<=(x-4)){
				bitNPlusOne=((uint32_t)0x80000000>>(x-regA-2))& frac64Z;
				bitsMore = ((0x7FFFFFFF>>(x-regA-2)) & frac64Z);
				fracA&=((int32_t)0x80000000>>(x-1));
			}
			else {
				if (regA==(x-2)){
					bitNPlusOne = expA&0x2;
					bitsMore = (expA&0x1);
					expA = 0;
				}
				else if (regA==(x-3)){
					bitNPlusOne = expA&0x1;
					expA &=0x2;
				}
				if (frac64Z>0){
					fracA=0;
					bitsMore =1;
				}

			}
			if (rem) bitsMore =1;
		}
		else{
			regime=(regSA) ? (regime & ((int32_t)0x80000000>>(x-1)) ): (regime << (32-x));
			expA=0;
			fracA=0;
		}

		expA <<= (28-regA);
		uZ.ui = packToP32UI(regime, expA, fracA);
		if (bitNPlusOne) uZ.ui += (uint32_t)(((uZ.ui>>(32-x))&1) | bitsMore) << (32-x) ;
	}

	if (signZ) uZ.ui = -uZ.ui & 0xFFFFFFFF;
	return uZ.p;
}

