/*============================================================================

This C source file is part of the SoftPosit Posit Arithmetic Package
by S. H. Leong (Cerlane).

Copyright 2017, 2018 A*STAR.  All rights reserved.

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

#include <inttypes.h>

#include "platform.h"
#include "internals.h"

quire16_t q16_fdp_sub( quire16_t q, posit16_t pA, posit16_t pB ){

	union ui16_p16 uA, uB;
	union ui128_q16 uZ, uZ1, uZ2;
	uint_fast16_t uiA, uiB;
	uint_fast16_t fracA, tmp;
	bool signA, signB, signZ2, regSA, regSB, rcarry;
	int_fast8_t expA;
	int_fast16_t kA=0, shiftRight;
	uint_fast32_t frac32Z;
	//For add
	bool rcarryb, b1, b2, rcarryZ;//, rcarrySignZ;

	uZ1.q = q;

	uA.p = pA;
	uiA = uA.ui;
	uB.p = pB;
	uiB = uB.ui;

	//NaR
	if (isNaRQ16(q) || isNaRP16UI(uA.ui) || isNaRP16UI(uB.ui)){
		uZ2.ui[0]=0x8000000000000000ULL;
		uZ2.ui[1] = 0;
		return uZ2.q;
	}
	else if (uiA==0 || uiB==0)
		return q;


	//max pos (sign plus and minus)
	signA = signP16UI( uiA );
	signB = signP16UI( uiB );
	signZ2 = signA ^ signB;

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

	rcarry = frac32Z>>29;//3rd bit (position 2) of frac32Z, hidden bit is 4th bit (position 3)
	if (rcarry){
		if (expA) kA ++;
		expA^=1;
		frac32Z>>=1;
	}

	//default dot is between bit 71 and 72, extreme left bit is bit 0. Last right bit is bit 127.
	//Scale = 2^es * k + e  => 2k + e
	int firstPos = 71 - (kA<<1) - expA;

	//No worries about hidden bit moving before position 4 because fraction is right aligned so
	//there are 16 spare bits
	if (firstPos>63){ //This means entire fraction is in right 64 bits
		uZ2.ui[0] = 0;
		shiftRight = firstPos-99;//99 = 63+ 4+ 32
		if (shiftRight<0)//shiftLeft
			uZ2.ui[1] =  ((uint64_t)frac32Z) << -shiftRight;
		else
			uZ2.ui[1] = (uint64_t) frac32Z >> shiftRight;
	}
	else{//frac32Z can be in both left64 and right64
		shiftRight = firstPos - 35;// -35= -3-32
		if (shiftRight<0)
			uZ2.ui[0]  = ((uint64_t)frac32Z) << -shiftRight;
		else{
			uZ2.ui[0] = (uint64_t)frac32Z >> shiftRight;
			uZ2.ui[1] =  (uint64_t) frac32Z <<  (64 - shiftRight);
		}

	}

	//This is the only difference from ADD (signZ2) and (!signZ2)
	if (!signZ2){
		if (uZ2.ui[1]>0){
			uZ2.ui[1] = - uZ2.ui[1];
			uZ2.ui[0] = ~uZ2.ui[0];
		}
		else{
			uZ2.ui[0] = -uZ2.ui[0];
		}
	}

	//Subtraction
	b1 = uZ1.ui[1]&0x1;
	b2 = uZ2.ui[1]&0x1;
	rcarryb = b1 & b2;
	uZ.ui[1] = (uZ1.ui[1]>>1) + (uZ2.ui[1]>>1) + rcarryb;

	rcarryZ = uZ.ui[1]>>63;

	uZ.ui[1] = (uZ.ui[1]<<1 | (b1^b2) );


	b1 = uZ1.ui[0]&0x1;
	b2 = uZ2.ui[0]&0x1;
	rcarryb = b1 & b2 ;
	int_fast8_t rcarryb3 = b1 + b2 + rcarryZ;

	uZ.ui[0] = (uZ1.ui[0]>>1) + (uZ2.ui[0]>>1) + ((rcarryb3>>1)& 0x1);
	//rcarrySignZ = uZ.ui[0]>>63;


	uZ.ui[0] = (uZ.ui[0]<<1 | (rcarryb3 & 0x1) );

	//Exception handling
	if (isNaRQ16(uZ.q)) uZ.q.v[0] = 0;

	return uZ.q;
}
