
/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017 2018 A*STAR.  All rights reserved.

This C source file was based on SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3d, by John R. Hauser.

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

posit_1_t pX2_to_pX1( posit_2_t pA, int x ){

	union ui32_pX2 uA;
	union ui32_pX1 uZ;
	uint_fast32_t uiA, tmp, regime;
	uint_fast32_t exp_frac32A=0;
	bool sign, regSA, bitNPlusOne, bitsMore;
	int_fast8_t kA=0, regA;


	if (x<2 || x>32){
		uZ.ui = 0x80000000;
		return uZ.p;
	}

	uA.p = pA;
	uiA = uA.ui;

	if (uiA==0x80000000 || uiA==0 ){
		uZ.ui = uiA;
		return uZ.p;
	}

	sign = signP32UI( uiA );
	if (sign) uiA = -uiA & 0xFFFFFFFF;


	regSA = signregP32UI(uiA);
	if (x==2){
		uZ.ui=(uiA>0)?(0x40000000):(0);
	}
	else {
		//regime
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
		//exp and frac
		exp_frac32A = tmp<<1;
		if(kA<0){
			regA = (-kA)<<1;
			if (exp_frac32A&0x80000000) regA--;
			exp_frac32A = (exp_frac32A<<1) &0xFFFFFFFF;
			regSA = 0;
			regime = 0x40000000>>regA;
		}
		else{
			regA = (kA<<1)+1;
			if (exp_frac32A&0x80000000) regA++;
			exp_frac32A = (exp_frac32A<<1) &0xFFFFFFFF;
			regSA=1;
			regime = 0x7FFFFFFF - (0x7FFFFFFF>>regA);
		}
		if(regA>(x-2)){
			//max or min pos. exp and frac does not matter.
			uZ.ui=(regSA) ? (0x7FFFFFFF & ((int32_t)0x80000000>>(x-1)) ): (0x1 << (32-x));
		}
		else{
			bitNPlusOne = (exp_frac32A >>(regA+33-x))&0x1;
			bitsMore = exp_frac32A&(0x7FFFFFFF>>(x-regA-2));

			if (regA<30) exp_frac32A >>=(2+regA);
			else exp_frac32A=0;
			uZ.ui = regime + (exp_frac32A & ((int32_t)0x80000000>>(x-1)) );

			if (uZ.ui==0) uZ.ui = 0x1<<(32-x);
			else if (bitNPlusOne){
				uZ.ui += (uint32_t)(((uZ.ui>>(32-x))&1) | bitsMore) << (32-x) ;
			}
		}
	}

    if (sign) uZ.ui = (-uZ.ui & 0xFFFFFFFF);
	return uZ.p;
}

