
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

posit_2_t pX1_to_pX2( posit_1_t pA, int x ){

	union ui32_pX1 uA;
	union ui32_pX2 uZ;
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
   /* else if (x==32 || (((uint32_t)0xFFFFFFFF>>x) & uiA)==0 ){
    	uZ.ui = uiA;
    }*/
    else {

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

		//2nd bit exp
		exp_frac32A = tmp;

		if(kA<0){
			regA = -kA;
			exp_frac32A |= ((uint32_t)(regA&0x1)<<31);
			regA = (regA+1)>>1;
			if (regA==0) regA=1;
			regSA = 0;
			regime = 0x40000000>>regA;
		}
		else{
			exp_frac32A |= ((uint32_t)(kA&0x1)<<31);
			(kA==0) ? (regA=1) : (regA = (kA+2)>>1);
			regSA=1;
			regime = 0x7FFFFFFF - (0x7FFFFFFF>>regA);
		}
		if(regA>(x-2)){
			//max or min pos. exp and frac does not matter.
			uZ.ui=(regSA) ? (0x7FFFFFFF & ((int32_t)0x80000000>>(x-1)) ): (0x1 << (32-x));
		}
		else{

//printBinary(&exp_frac32A, 32);
//uint32_t temp = (0x7FFFFFFF>>(x-regA-2));
//printBinary(&temp, 32);
//printBinary(&regime, 32);
			bitNPlusOne = (exp_frac32A >>(regA+33-x))&0x1;
			bitsMore = exp_frac32A&(0x7FFFFFFF>>(x-regA-2));
//printf("bitNPlusOne: %d bitsMore: %d\n", bitNPlusOne, bitsMore);
			exp_frac32A >>= (regA+2); //2 because of sign and regime terminating bit
			uZ.ui = regime + (exp_frac32A & ((int32_t)0x80000000>>(x-1)) );
//printBinary(&uZ.ui, 32);
			//int shift = 32-x;
			/*if( (uiA>>shift)!=(0x7FFFFFFF>>shift) ){
				if( ((uint32_t)0x80000000>>x) & uZ.ui){
					if ( ( ((uint32_t)0x80000000>>(x-1)) & uZ.ui) || (((uint32_t)0x7FFFFFFF>>x) & uZ.ui) )
						uZ.ui += (0x1<<shift);
				}
			}

			uZ.ui &=((int32_t)0x80000000>>(x-1));*/
			if (uZ.ui==0) uZ.ui = (uint32_t)0x1<<(32-x);
			else if (bitNPlusOne){
				uZ.ui += (uint32_t)(((uZ.ui>>(32-x))&1) | bitsMore) << (32-x) ;
			}
		}

    }
    if (sign) uZ.ui = (-uZ.ui & 0xFFFFFFFF);
	return uZ.p;
}

